#!/bin/sh
#
# This script runs both WebUI unit and integration tests 
#

###############################################################################
# Job configuration template
###############################################################################
#
# Project name: obs_testsuite_webui
# Description:
#   OBS WebUI testsuite on git master branch.
#
#   Updates source code repository and runs unit and integration tests.
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
#     Command: sh dist/ci/obs_testsuite_webui.sh
#
# Post Build Actions:
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

cd src/webui

export HEADLESS=forsure

echo "Invoke rake"
bundle exec rake ci:setup:minitest test CI_REPORTS=results --trace || ret=1
cd ../..

echo "Contents of src/api/log/test.log:"
cat src/api/log/test.log
echo

echo "Contents of src/webui/log/test.log:"
cat src/webui/log/test.log
echo

cleanup
exit $ret
