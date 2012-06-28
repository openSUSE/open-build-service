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

case $SUBTEST in
  api)
   echo "Enter API rails root and running rcov"
   cd src/api
   bundle exec rake --trace ci:setup:testunit test CI_REPORTS=results || ret=1
   ;;
  webui)
   echo "Enter WebUI rails root and running rcov"
   cd src/webui
   bundle exec rake --trace ci:setup:testunit test CI_REPORTS=results || ret=1
   ;;
  webui-testsuite)
   cd src/webui-testsuite
   rm ./tests/TC80__Spider.rb
   bundle exec ./run_acceptance_tests.rb || ret=1
   ;;
  webui-gemshead)
   cd src/api
   bundle exec rake --trace ci:setup:testunit test CI_REPORTS=results || ret=1
   cd ../webui
   rake --trace ci:setup:testunit test CI_REPORTS=results || ret=1
   ;;
  webui-testsuite:*)
   cd src/webui-testsuite
   SUBTEST=${SUBTEST/webui-testsuite:/}
   bundle exec ruby ./run_acceptance_tests.rb -f $SUBTEST || ret=1
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

