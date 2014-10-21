#!/bin/bash


SSH_OPTS='-o StrictHostKeyChecking=no -oNumberOfPasswordPrompts=0 -n -t -t'
SCP_OPTIONS='-o StrictHostKeyChecking=no'


declare -a nodes=($(awk -F":" '{ print $1 }' cluster.roles ))


## Check the Prerequisites
#1. Check the Keyless SSH among the nodes
	keyless=1
	for node in ${nodes[@]}
	do
		/usr/bin/ssh ${SSH_OPTS} $node echo hello > /dev/null 2>&1 || keyless=0
	done
	if [ $keyless -eq 0 ] ; then
		echo
		echo "Keyless ssh needs to be enabled between the nodes ! "
		echo
		exit 1;
	else 
		echo "Keyless ssh is be enabled between the nodes ! "
	fi

#2.Check for JAVA_HOME and disks 

	prereq=1	
	for node in ${nodes[@]}
	do
		echo 
		echo "On Node : $node.."
		scp cluster.roles cluster.properties pernode_prereq.sh pernode_install.sh $node:/tmp/ >/dev/null 2>&1 
		/usr/bin/ssh ${SSH_OPTS} $node "/tmp/pernode_prereq.sh" || prereq=0
	done
	if [ $prereq -eq 0 ] ; then
		echo
		echo "Installation ABORTED !! Please verify Pre-Reqs !!"
		exit 1;	
	fi

#echo "We are Thru"
#3. Pass on the installer files to all cluster nodes and run the installer

	for node in ${nodes[@]}
	do
		echo
		echo "Installing and Setting up node : $node.."
		/usr/bin/ssh ${SSH_OPTS} $node "/tmp/pernode_install.sh >> /tmp/cluster_script.log" 
	done

