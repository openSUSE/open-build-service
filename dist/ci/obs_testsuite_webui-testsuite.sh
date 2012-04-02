#!/bin/sh
#
# This script runs WebUI selenium tests
#

###############################################################################
# Job configuration template
###############################################################################
#
# Project name: obs_testsuite_webui-testsuite
# Description:
#   OBS WebUI selenium testsuite on git master branch.
#
#   Updates source code repository and runs webui-testsuite.
#
# Source Code Management:
#   Git:
#     Repositories: git://github.com/openSUSE/open-build-service.git
#     Branches to build: master
#     Repository browser: githubweb
#       URL: https://github.com/openSUSE/open-build-service
#     Excluded Regions:
#       docs
#
# Build Triggers:
#   Poll SCM:
#     Schedule: */5 * * * *
#
# Build:
#   Execute shell:
#     Command: sh dist/ci/obs_testsuite_webui-testsuite.sh
#
# Post Build Actions: #FIXME
#   Publish JUnit test result report:
#     Test report XMLs: src/webui/results/*.xml
#   Publish Rails Notes report: 1
#     Rake working directory: src/webui
#   Publish Rails stats report: 1
#     Rake working directory: src/webui
#

###############################################################################
# Script content for 'Build' step
###############################################################################
#
# Either invoke as described above or copy into an 'Execute shell' 'Command'.
#

set -xe
. `dirname $0`/obs_testsuite_common.sh

setup_git
setup_api
setup_webui

echo "Running Acceptance Tests"
cd src/webui-testsuite
export OBS_REPORT_DIR=results/
ruby ./run_acceptance_tests.rb || ret=1

cd ../..

echo "Contents of src/api/log/test.log:"
cat src/api/log/test.log
echo

echo "Contents of src/webui/log/test.log:"
cat src/webui/log/test.log
echo

cleanup
exit $ret

