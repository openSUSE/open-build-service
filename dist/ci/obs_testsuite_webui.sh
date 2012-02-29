#!/bin/sh
#
# This script runs both WebUI unit and integration tests and produces coverage
# and todo/fixme reports as well as code statistics.
#

###############################################################################
# Job configuration template
###############################################################################
#
# Project name: obs_testsuite_webui
# Description:
#   OBS WebUI testsuite on git master branch.
#
#   Runs unit and integration tests, generated coverage reports.
#
# Build Triggers:
#   Build after other projects are built:
#     Project names: obs_testsuite_api
#
# Build:
#   Copy artifacts from another project:
#     Project name: obs_testsuite_api
#     Artifacts to copy: **/*
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
#   Publish Rcov report:
#     Rcov report directory:  src/webui/coverage/test
#

###############################################################################
# Script content for 'Build' step
###############################################################################
#
# Either invoke as described above or copy into an 'Execute shell' 'Command'.
#

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
rake db:drop db:create db:migrate

echo "Invoke rake"
rake ci:setup:testunit test CI_REPORTS=results
rake test:rcov
cd ../..

echo "Contents of src/api/log/test.log:"
cat src/api/log/test.log
echo

echo "Contents of src/webui/log/test.log:"
cat src/webui/log/test.log
echo

echo "Remove log/tmp files to save disc space"
rm -rf src/api/{log,tmp}/* \
       src/webui/{log,tmp,coverage,results}/*
