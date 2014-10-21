#!/bin/bash


##### 1. Set the CDH repo and import the GPG Key
cdhrelease=$(/bin/grep release= /tmp/cluster.properties | /bin/awk -F"=" '{ print $2 }')
/bin/cat > /etc/yum.repos.d/cloudera-cdh5.repo <<EOF
[cloudera-cdh5]
# Packages for Cloudera's Distribution for Hadoop, Version 5, on RedHat	or CentOS 6 x86_64
name=Cloudera's Distribution for Hadoop, Version 5
baseurl=http://archive.cloudera.com/cdh5/redhat/6/x86_64/cdh/${cdhrelease}/
gpgkey = http://archive.cloudera.com/cdh5/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera    
gpgcheck = 1
EOF

/bin/rpm --import http://archive.cloudera.com/cdh5/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera

##### 2. Install the hadoop packages.
nodeIP=$(/sbin/ifconfig | /bin/grep "inet addr" | /bin/grep -v "127.0.0.1" | /bin/awk '{ print $2 }' | /bin/cut -d":" -f2 | /usr/bin/head -1)
declare -a noderoles="($(/bin/grep ${nodeIP}: /tmp/cluster.roles | tr ':' ' '))"
for role in ${noderoles[@]:1}
do
	yum -y install hadoop-${role}
done

##### 3. Create the Hadoop Conf directory and update-alternatives
confdir=$(/bin/grep conf_dir= /tmp/cluster.properties | /bin/awk -F"=" '{ print $2 }')

cp -r /etc/hadoop/conf.empty /etc/hadoop/${confdir}
/usr/sbin/alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/${confdir} 50
/usr/sbin/alternatives --set hadoop-conf /etc/hadoop/${confdir}

#### Defind Function for Generate XML file

generatexml() {

	declare -a argslist=("${!1}")
	echo "<?xml version=\"1.0\"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>"
	for line in ${argslist[@]}
	do
		declare -a tuple=(${line//=/ })
		#echo ${tuple[@]}
		echo " <property>"
		echo "  <name>${tuple[0]}</name>"
		echo "  <value>${tuple[1]}</value>"
		echo " </property>"
	done
echo "</configuration>"
}
#### Function definition ends


#declare -a properties=($(grep "hdfs_site#"  cluster.properties  | cut -d"#" -f2))
#echo ${properties[@]}
#generatexml properties[@]


#4. Generate the HDFS conf files
namenodeIP=$(/bin/grep hdfs-namenode /tmp/cluster.roles | /bin/cut -d":" -f1)

## Update the core-site.xml properties for the hdfs:// URI
##if [ "$nodeIP" = "$namenodeIP" ] ; then
##	#cmd="/bin/sed -i '/core_site#fs.defaultFS=/s/^.*$/core_site#fs.defaultFS=hdfs:\/\/0.0.0.0:8020/\' /tmp/cluster.properties"
##	/bin/sed -i "/core_site#fs.defaultFS=/s/^.*$/core_site#fs.defaultFS=hdfs:\/\/0.0.0.0:8020/" /tmp/cluster.properties
##else
##	/bin/sed -i "/core_site#fs.defaultFS=/s/^.*$/core_site#fs.defaultFS=hdfs:\/\/${namenodeIP}:8020/" /tmp/cluster.properties
##fi
	/bin/sed -i "/core_site#fs.defaultFS=/s/^.*$/core_site#fs.defaultFS=hdfs:\/\/${namenodeIP}:8020/" /tmp/cluster.properties


#### 5. Create Datanode data dirs

if /bin/grep ${nodeIP} /tmp/cluster.roles | /bin/grep hdfs-datanode >/dev/null 2>&1
then
	declare -a datadisks=($(lsblk --noheadings --nodeps -o name | egrep -v "sr0|sda"))
	diskindex=1
	datadirs=""
	yarnlocaldirs=""
	yarnlogdirs=""
	for disk in ${datadisks[@]}
	do
		/sbin/dumpe2fs -h /dev/${disk} >/dev/null 2&1 ||  /sbin/mkfs.ext4 -F /dev/${disk}
		mkdir -p /dfs/${diskindex}
		/bin/grep /dfs/${diskindex} /etc/fstab >/devnull || echo "/dev/${disk}	/dfs/${diskindex}	ext4	defaults	0 0" >> /etc/fstab
		/bin/mount | /bin/grep /dfs/${diskindex} >/dev/null 2>&1 || mount /dfs/${diskindex}

		mkdir -p /dfs/${diskindex}/data 
		chown hdfs:hdfs /dfs/${diskindex}/data
		chmod 700 /dfs/${diskindex}/data
		datadirs+="/dfs/${diskindex}/data,"
		
		# yarn dirs
		mkdir -p /dfs/${diskindex}/yarn/local /dfs/${diskindex}/yarn/logs
		chown yarn:yarn /dfs/${diskindex}/yarn/local /dfs/${diskindex}/yarn/logs
		chmod 755 /dfs/${diskindex}/yarn/local /dfs/${diskindex}/yarn/logs
		yarnlocaldirs+="/dfs/${diskindex}/yarn/local,"
		yarnlogdirs+="/dfs/${diskindex}/yarn/logs,"

		diskindex=`expr $diskindex + 1`
	done
	#echo $datadirs
	datadirs=`echo $datadirs | sed 's/,$//'`
        /bin/sed -i '/hdfs_site#dfs.data.dir=/s|^.*$|hdfs_site#dfs.data.dir='"${datadirs}"'|' /tmp/cluster.properties

	yarnlocaldirs=`echo $yarnlocaldirs | sed 's/,$//'`
	yarnlogdirs=`echo $yarnlogdirs | sed 's/,$//'`
fi
	
#### 6. Create NameNode Namedir and format HDFS
if [ "$nodeIP" = "$namenodeIP" ] ; then
	for namedir in `/bin/grep dfs.name.dir /tmp/cluster.properties  | cut -d"=" -f2 | tr ',' ' '` 	
	do
		mkdir -p ${namedir}
		chown hdfs:hdfs ${namedir}
		chmod 700 ${namedir}
	done
	namedir1=$(/bin/grep dfs.name.dir /tmp/cluster.properties  | cut -d"=" -f2 | cut -d"," -f1)

	if [  "$(ls -A ${namedir1} 2>/dev/null )" == "" ] ; then
		#echo "I am here"
		/usr/bin/yes Y | /usr/bin/sudo -u hdfs /usr/bin/hadoop namenode -format 
	fi
fi

##### 7.  Generate core-site.xml and hdfs-site.xml
#echo ${properties[@]}
declare -a properties=($(grep "^core_site#"  /tmp/cluster.properties  | cut -d"#" -f2))
#echo "Mitra core-site.prp"
#echo ${properties[@]}
generatexml properties[@] > /etc/hadoop/conf/core-site.xml

#echo "Mitra hdfs-site.prp"
declare -a properties=($(grep "^hdfs_site#"  /tmp/cluster.properties  | cut -d"#" -f2))
generatexml properties[@] > /etc/hadoop/conf/hdfs-site.xml

#### 8.  Start HDFS
for service in `cd /etc/init.d/ ; ls hadoop-hdfs-*`
do
	service $service restart
done

### HDFS set-up is done.
#### Yarn set-up follows.

#### 9. Create /tmp and other directories in HDFS
sleep 10
if [ "$nodeIP" = "$namenodeIP" ] ; then
	/usr/bin/sudo -u hdfs hadoop fs -mkdir /tmp
	/usr/bin/sudo -u hdfs hadoop fs -chmod -R 1777 /tmp

	/usr/bin/sudo -u hdfs hadoop fs -mkdir -p /user/history >/dev/null 2>&1
	/usr/bin/sudo -u hdfs hadoop fs -chmod -R 1777 /user/history >/dev/null 2>&1
	/usr/bin/sudo -u hdfs hadoop fs -chown yarn /user/history >/dev/null 2>&1

	/usr/bin/sudo -u hdfs hadoop fs -mkdir -p /var/log/hadoop-yarn >/dev/null 2>&1
	/usr/bin/sudo -u hdfs hadoop fs -chown yarn:mapred /var/log/hadoop-yarn >/dev/null 2>&1
fi
#### 10. Generate mapred-site.xml and yarn-site.xml
## mapred-stie.xml
hsIP=$(/bin/grep mapreduce-historyserver /tmp/cluster.roles | /bin/cut -d":" -f1)
/bin/sed -i "/^mapred_site#mapreduce.jobhistory/s/hsIP/${hsIP}/" /tmp/cluster.properties
declare -a properties=($(grep "^mapred_site#"  /tmp/cluster.properties  | cut -d"#" -f2))
generatexml properties[@] > /etc/hadoop/conf/mapred-site.xml

rmIP=$(/bin/grep yarn-resourcemanager /tmp/cluster.roles | /bin/cut -d":" -f1)

## yarn-site.xml
/bin/sed -i "/^yarn_site#yarn.resourcemanager/s/rmIP/${rmIP}/" /tmp/cluster.properties
/bin/sed -i '/yarn_site#yarn.nodemanager.local-dirs=/s|^.*$|yarn_site#yarn.nodemanager.local-dirs='"${yarnlocaldirs}"'|' /tmp/cluster.properties
/bin/sed -i '/yarn_site#yarn.nodemanager.log-dirs=/s|^.*$|yarn_site#yarn.nodemanager.log-dirs='"${yarnlogdirs}"'|' /tmp/cluster.properties

declare -a properties=($(grep "^yarn_site#"  /tmp/cluster.properties  | cut -d"#" -f2))
generatexml properties[@] > /etc/hadoop/conf/yarn-site.xml

## 11. Start Yarn
for service in `cd /etc/init.d/ ; ls hadoop-yarn-*`
do
	service $service restart
done
