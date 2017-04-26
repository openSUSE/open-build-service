#!/bin/bash

RCODE=0
# plan
echo "1..1"

BASE_DIR=$(dirname $0)

#export BASH_TAP_ROOT=$BASE_DIR
#. $BASE_DIR/../bash-tap-bootstrap

TMP_DIR=$BASE_DIR/tmp

rm -rf $TMP_DIR
mkdir -p $TMP_DIR
cd $TMP_DIR

osc co home:Admin
cd home\:Admin
mkdir obs-testpackage
osc add obs-testpackage
cd obs-testpackage
cp $BASE_DIR/fixtures/obs-testpackage._service ./_service
osc ar
osc ci -m "initial version"
osc r -w


got=`osc r|grep succeeded|wc -l`

if [ $got -eq 2 ];then
  echo "ok - Checking build results"
else
  echo "not ok - Checking build results"
  RCODE=1
fi

exit $RCODE
