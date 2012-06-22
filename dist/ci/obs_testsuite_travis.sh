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
   rake --trace ci:setup:testunit test CI_REPORTS=results || ret=1
   ;;
 webui)
   echo "Enter WebUI rails root and running rcov"
   cd src/webui
   rake --trace ci:setup:testunit test CI_REPORTS=results || ret=1
   ;;
 webui-testsuite)
   cd src/webui-testsuite
   rm ./tests/TC80__Spider.rb
   ruby ./run_acceptance_tests.rb || ret=1
   ;;
 webui-testsuite-spider)
   cd src/webui-testsuite
   ruby ./run_acceptance_tests.rb spider_anonymously || ret=1
   ;;
esac

cd ../..
cleanup
exit $ret

