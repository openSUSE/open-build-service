#!/bin/bash

# plan 
echo "1..1"

BASE_DIR=$(dirname $0)
TMP_DIR=$BASE_DIR/tmp
cd $TMP_DIR/home\:Admin
osc delete obs-testpackage

if [ $? -gt 0 ];then
  echo "not ok - Deleting package obs-testpackage"
else
  echo "ok - Deleting package obs-testpackage"
fi

osc ci -m "removed package obs-testpackage"
