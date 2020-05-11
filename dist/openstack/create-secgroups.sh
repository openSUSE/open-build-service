#!/bin/bash

NEUTRONCLIENT=`type -p neutron`
if [ -z "$NEUTRONCLIENT" ];then
	echo "Please install neutron client!"
	exit 1
fi

if [ -z "$1" ];then
	echo "Usage: "`basename $0`" <OBSSERVER_IP>"
	exit 1
else
	OBSSERVER_IP=$1
fi

if [ -n "$2" -a -n "$3" ];then
   SEC_GROUP_NAME=$2
   CREATE_SEC_GROUP=$3
else
   CREATE_SEC_GROUP="server worker"
fi

function create_secgroup_obsserver {

	if [ -z "$SEC_GROUP_NAME" ];then
	  SEC_GROUP_NAME=obs-server
        fi
	neutron security-group-create $SEC_GROUP_NAME
	SEC_GROUP_ID=$(neutron security-group-list  -f csv -F id -F name | grep $SEC_GROUP_NAME | cut -f1 -d',' | tr -d '"')
 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 22 --port-range-max 22 --protocol tcp $SEC_GROUP_ID
 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 80 --port-range-max 80 --protocol tcp $SEC_GROUP_ID
 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 443 --port-range-max 443 --protocol tcp $SEC_GROUP_ID
 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 5252 --port-range-max 5252 --protocol tcp $SEC_GROUP_ID
 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 5352 --port-range-max 5352 --protocol tcp $SEC_GROUP_ID
 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 427 --port-range-max 427 --protocol udp $SEC_GROUP_ID

}

function create_secgroup_obsworker {

	if [ -z "$SEC_GROUP_NAME" ];then
	  SEC_GROUP_NAME=obs-worker
        fi
	neutron security-group-create $SEC_GROUP_NAME

	SEC_GROUP_ID=$(neutron security-group-list  -f csv -F id -F name | grep $SEC_GROUP_NAME | cut -f1 -d',' | tr -d '"')

 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 1 --port-range-max 65535 --protocol tcp --remote-ip-prefix $OBSSERVER_IP/32 $SEC_GROUP_ID
 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 1 --port-range-max 65535 --protocol udp --remote-ip-prefix $OBSSERVER_IP/32 $SEC_GROUP_ID
	# TODO: Restrict egress also to $OBSSERVER
}


for i in $CREATE_SEC_GROUP
do
  FNAME=create_secgroup_obs$i
  $FNAME
done
