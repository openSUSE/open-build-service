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
  api)
   echo "Enter API rails root and running rcov"
   cd src/api
   bundle exec rake test --trace || ret=1
   ;;
  webui1|webui2)
   echo "Enter WebUI rails root and running rcov"
   cd src/webui
   if test "$SUBTEST" = "webui2"; then
     rm -v test/functional/[a-m]*_test.rb
   else
     rm -v test/functional/[n-z]*_test.rb
   fi
   bundle exec rake test --trace || ret=1
   ;;
  webui:*)
   echo "Enter WebUI rails root"
   cd src/webui
   SUBTEST=${SUBTEST/webui:/}
   thetest=${SUBTEST/:*/}
   thename=${SUBTEST/*:/}
   if test "$thename" != "$thetest"; then
     thename="--name=$thename"
   else
     thename=
   fi
   if ! bundle exec ruby test/$thetest $thename ; then
     ret=1
     cat log/test.log
   fi
   ;;
  api:*)
   cd src/api
   SUBTEST=${SUBTEST/api:/}
   thetest=${SUBTEST/:*/}
   thename=${SUBTEST/*:/}
   bundle exec ruby test/$thetest --name=$thename || ret=1
   cat log/test.log
   ;;
esac

cd ../..
cleanup
exit $ret

