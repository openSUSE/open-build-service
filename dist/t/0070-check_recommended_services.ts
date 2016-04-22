#!/bin/bash

export BASH_TAP_ROOT=$(dirname $0)

. $(dirname $0)/bash-tap-bootstrap

plan tests 6

MAX_WAIT=300

tmpcount=$MAX_WAIT

# Service enabled and started
for srv in \
obsdodup \
obsstoragesetup \
obssigner \
obsdeltastore
do
  STATE=` systemctl is-enabled $srv\.service 2>/dev/null`
  is "$STATE" "enabled" "Checking recommended service '$srv' enabled"
  ACTIVE=`systemctl is-active $srv\.service`
  while [[ $ACTIVE != 'active' ]];do
    tmpcount=$(( $tmpcount - 1 ))
    ACTIVE=`systemctl is-active $srv\.service`
    if [[ $tmpcount -le 0 ]];then
      ACTIVE='timeout'
      break
    fi
    sleep 1
  done
  is "$ACTIVE" "active" "Checking recommended service '$srv' status"
done
