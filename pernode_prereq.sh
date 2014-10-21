#!/bin/bash


#1.Check JAVA_HOME
# For CDH install Oracle Java need to be installed and JAVA_HOME need to be set

	javahome_path=$(grep JAVA_HOME /tmp/cluster.properties | awk -F"=" '{ print $2 }') 

	javahome=1
	ls ${javahome_path}/bin/java  > /dev/null 2>&1 || javahome=0
	if [ $javahome -eq 0 ] ; then
		echo "CDH requires Oracel Java to be installed and JAVA_HOME need to be defined on all nodes! "
	else 
		echo "Found java at specified JAVA_HOME location !"	
	fi


#2. Check for unused disks for datanodes

	disksavailable=$(lsblk --noheadings --nodeps -o name | egrep -v "sr0|sda" | wc -l)
	if [[ $disksavailable -ge 1 ]] 
	then
		echo "Found disk for data ! "
	else
		echo "No disks available for data !!"

	fi

if [[ $javahome -eq 1 ]] && [[ $disksavailable -ge 1 ]] ; then
	exit 0;
else
	exit 1;
fi
