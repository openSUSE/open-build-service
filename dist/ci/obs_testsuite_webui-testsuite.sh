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
#   Updates source code repository and runs webui-testsuite. It also
#   generates coverage reports.
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
#   Publish Rcov report:
#     Rcov report directory:  src/webui/coverage
#

###############################################################################
# Script content for 'Build' step
###############################################################################
#
# Either invoke as described above or copy into an 'Execute shell' 'Command'.
#

set -xe
sh -xe `dirname $0`/obs_testsuite_common.sh

echo "Enter WebUI rails root"
cd src/webui

echo "Setup database configuration"
cp config/database.yml.example config/database.yml

echo "Setup additional configuration"
cp config/options.yml.example config/options.yml

echo "Install missing gems locally"
#rake gems:install # TODO: Fix webui to make this work!

echo "Set environment variables"
export RAILS_ENV=test

echo "Fix executable bits broken by 'Copy Artifacts' plugin"
chmod +x script/start_test_api \
         ../api/script/server \
         ../api/script/start_test_backend

echo "Initialize test database, run migrations, load seed data"
rake --trace db:drop db:create db:migrate

echo "Running Acceptance Tests"
cd ../webui-testsuite
ruby ./run_acceptance_tests.rb

cd ../..

echo "Contents of src/api/log/test.log:"
cat src/api/log/test.log
echo

echo "Contents of src/webui/log/test.log:"
cat src/webui/log/test.log
echo

echo "Remove log/tmp files to save disc space"
rm -rf src/api/{log,tmp}/* \
       src/webui/{log,tmp}/*
