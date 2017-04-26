#!/bin/bash

BASE_DIR=$(dirname $0)

#export BASH_TAP_ROOT=$BASE_DIR
#. $BASE_DIR/../bash-tap-bootstrap

# plan
echo "1..1"

osc meta prj openSUSE.org -F $BASE_DIR/fixtures/openSUSE.org.xml

if [ $? -gt 0 ];then
  echo "not ok - Creation of interconnect project"
else
  echo "ok - Creation of interconnect project"
fi

exit 0
