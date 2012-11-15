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

export OBS_REPORT_DIR=results/

case $SUBTEST in
  api)
   echo "Enter API rails root and running rcov"
   cd src/api
   bundle exec rake ci:setup:minitest test CI_REPORTS=results --trace || ret=1
   ;;
  webui)
   echo "Enter WebUI rails root and running rcov"
   cd src/webui
   bundle exec rake ci:setup:minitest test CI_REPORTS=results --trace || ret=1
   ;;
  webui-testsuite)
   cd src/webui-testsuite
   rm ./tests/TC80__Spider.rb
   if ! bundle exec ./run_acceptance_tests.rb -f; then
     ret=1
     tail -n 500 ../webui/log/test.log
     cat results/*.source.html
   fi
   ;;
  webui-gemshead)
   cd src/api
   bundle exec rake ci:setup:minitest test CI_REPORTS=results --trace || ret=1
   cd ../webui
   rake ci:setup:minitest test CI_REPORTS=results --trace || ret=1
   ;;
  webui-testsuite:*)
   cd src/webui-testsuite
   SUBTEST=${SUBTEST/webui-testsuite:/}
   if ! bundle exec ruby ./run_acceptance_tests.rb -f $SUBTEST; then
     ret=1
     tail -n 500 ../webui/log/test.log
     cat results/*.source.html
   fi
   ;;
  webui:*)
   echo "Enter WebUI rails root"
   cd src/webui
   SUBTEST=${SUBTEST/webui:/}
   thetest=${SUBTEST/:*/}
   thename=${SUBTEST/*:/}
   bundle exec ruby test/$thetest --name=$thename || ret=1
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

