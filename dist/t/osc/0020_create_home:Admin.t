#!/bin/bash

# plan
echo "1..1"

BASE_DIR=$(dirname $0)
TMP_DIR=$BASE_DIR/tmp

osc meta prj home:Admin -F $BASE_DIR/fixtures/home\:Admin.xml

if [ $? -gt 0 ];then
  echo "not ok - Creation of home:Admin project"
else
  echo "ok - Creation of home:Admin project"
fi

exit 0
