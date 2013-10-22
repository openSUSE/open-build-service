#!/bin/sh
#
# This script runs all build service test suites depending on $SUBTEST
#

###############################################################################
# Script content for 'Build' step
###############################################################################
#
# Either invoke as described above or copy into an 'Execute shell' 'Command'.
#

set -xe

. `dirname $0`/obs_testsuite_common.sh

ret=0
export OBS_REPORT_DIR=results/
export HEADLESS=forsure

case $SUBTEST in
  rake:*)
   echo "Enter API rails root and running rcov"
   cd src/api
   SUBTEST=${SUBTEST/rake:/}
   bundle exec rake $SUBTEST --trace || ret=1
   tail -n 6000 log/test.log
   ;;
  api:*)
   cd src/api
   SUBTEST=${SUBTEST/api:/}
   thetest=${SUBTEST/:*/}
   thename=${SUBTEST/*:/}
   bundle exec ruby -Itest test/$thetest --name=$thename || ret=1
   tail -n 6000 log/test.log
   ;;
esac

cd ../..
cleanup
exit $ret

