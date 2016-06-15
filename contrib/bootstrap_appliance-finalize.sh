#!/bin/bash

echo "Waiting 60 sec to give obsapisetup chance to finish"
sleep 60
make -C /vagrant/dist t ts
echo -en "\n\n\n"
echo -en "\n\n\n"
echo -en "Visit this URL to login https://"$(ip route show|grep "scope link"|perl -p -e 's/.* src ([0-9\.]+)/$1/')
echo -en "\n\n\n"
echo "!!!!!!!!   Finished  Installation !!!!!!!"
