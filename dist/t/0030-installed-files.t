#!/bin/bash
#
export BOOTSTRAP_TEST_MODE=1
export NON_INTERACTIVE=1
export BASH_TAP_ROOT=$(dirname $0)
#
. $(dirname $0)/bash-tap-bootstrap
#
plan tests 5
for i in \
    $DESTDIR/etc/logrotate.d/obs-server\
    $DESTDIR/usr/sbin/obs_admin\
    $DESTDIR/usr/sbin/obs_serverstatus
do
  [[ -e $i ]]
  is $? 0 "Checking $i"

done

for i in \
    $DESTDIR/usr/sbin/rcobssrcserver\
    $DESTDIR/usr/sbin/rcobsdodup
do
  [[ -L $i ]]
  is $? 0 "Checking $i"
done
