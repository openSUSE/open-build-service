#!/bin/sh
#
# This script runs both API unit and integration tests and produces coverage
# and todo/fixme reports as well as code statistics.
#

###############################################################################
# Job configuration template
###############################################################################
#
# Project name: obs_testsuite_api
# Description:
#   OBS API testsuite on git master branch.
#
#   Updates source code repository and sets up a working environment for all
#   further tasks. Runs unit and integration tests generated coverage reports.
#
# Source Code Management:
#   Git:
#     Repositories: git://github.com/openSUSE/open-build-service.git
#     Branches to build: master
#
# Build Triggers:
#   Poll SCM:
#     Schedule: */5 * * * *
#
# Build:
#   Execute shell:
#     Command: sh dist/ci/obs_testsuite_api.sh
#
# Post Build Actions:
#   Archive the artifacts:
#     Files to archive: **/*
#     Discard all but the last successful/stable artifact to save disk space: 1
#   Publish JUnit test result report:
#     Test report XMLs: src/api/results/*.xml
#   Publish Rails Notes report: 1
#     Rake working directory: src/api
#   Publish Rails stats report: 1
#     Rake working directory: src/api
#   Publish Rcov report:
#     Rcov report directory:  src/api/coverage/test
#

###############################################################################
# Script content for 'Build' step
###############################################################################
#
# Either invoke as described above or copy into an 'Execute shell' 'Command'.
#

echo "Setup git submodules"
git submodule init
git submodule update

echo "Setup backend configuration template"
sed -i -e "s|my \$hostname = .*$|my \$hostname = 'localhost';|" \
       -e "s|our \$bsuser = 'obsrun';|our \$bsuser = 'jenkins';|" \
       -e "s|our \$bsgroup = 'obsrun';|our \$bsgroup = 'jenkins';|" src/backend/BSConfig.pm.template
cp src/backend/BSConfig.pm.template src/backend/BSConfig.pm

echo "Enter API rails root"
cd src/api

echo "Setup database configuration"
cp config/database.yml.example config/database.yml
sed -i "s|database: api|database: ci_api|" config/database.yml

echo "Setup additional configuration"
cp config/options.yml.example config/options.yml

echo "Install missing gems locally and fetch rails_rcov"
rake gems:install
ruby script/plugin install http://svn.codahale.com/rails_rcov

echo "Set environment variables"
export CI_REPORTS=results
export RAILS_ENV=test

echo "Initialize test database, run migrations, load seed data"
rake db:drop db:create db:setup db:migrate

echo "Prepare for rcov"
[ -d "coverage" ] && rm -rf coverage
mkdir coverage

echo "Invoke rake"
rake ci:setup:testunit test:test:rcov --trace RCOV_PARAMS="--aggregate coverage/aggregate.data"

echo "Remove unneded files to save disc space"
rm -rf src/api/log/* \
       src/api/tmp/*
