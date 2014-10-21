#!/bin/bash

	datadirs="/dfs/a,/dfs/b,v,d,d,"
        datadirs=`echo $datadirs | sed 's/,$//'`
	echo $datadirs

/bin/sed  '/hdfs_site#dfs.data.dir=/s|^.*$|hdfs_site#dfs.data.dir='"${datadirs}"'|' /tmp/cluster.properties
rmIP=1.2.3.4
/bin/sed  "/^yarn_site#yarn.resourcemanager/s/rmIP/${rmIP}/" cluster.properties

dir="../work2"
if [[ -z $(ls ${dir}) ]]
then
	echo MItra
fi
read a 
read b
read c
echo $a $b $c

