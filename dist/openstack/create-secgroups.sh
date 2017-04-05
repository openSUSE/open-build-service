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

function create_secgroup_obsserver {

	SEC_GROUP_NAME=obs-server
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

	SEC_GROUP_NAME=obs-worker
	neutron security-group-create $SEC_GROUP_NAME

	SEC_GROUP_ID=$(neutron security-group-list  -f csv -F id -F name | grep $SEC_GROUP_NAME | cut -f1 -d',' | tr -d '"')

 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 1 --port-range-max 65535 --protocol tcp --remote-ip-prefix $OBSSERVER_IP/32 $SEC_GROUP_ID
 	neutron security-group-rule-create --direction ingress --ethertype IPv4 --port-range-min 1 --port-range-max 65535 --protocol udp --remote-ip-prefix $OBSSERVER_IP/32 $SEC_GROUP_ID
	# TODO: Restrict egress also to $OBSSERVER
}

create_secgroup_obsserver
create_secgroup_obsworker
