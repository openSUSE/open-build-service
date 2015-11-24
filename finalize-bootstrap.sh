#!/bin/bash

echo "Waiting 60 sec to give obsapisetup chance to finish"
sleep 60
cd /vagrant/dist
echo -en "\n\n\n"
prove t
echo -en "\n\n\n"
echo -en "Visit this URL to login https://"$(ip route show|grep "scope link"|perl -p -e 's/.* src ([0-9\.]+)/$1/')
echo -en "\n\n\n"
echo "!!!!!!!!   Finished  Installation !!!!!!!"
