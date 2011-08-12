#!/bin/sh
#
# This script creates a OBS git checkout and initial OBS backend configuration.
#

###############################################################################
# Job configuration template
###############################################################################
#
# Project name: obs_common
# Description:
#   OBS common tasks. Updates source code repository and sets up a working
#   environment for all further tasks.
#
# Discard Old Builds:
#   Days to keep builds: 5
#   Max # of builds to keep: 5
#
# Source Code Management:
#   Git:
#     Repositories: git://gitorious.org/opensuse/build-service.git
#     Branches to build: master
#
# Build Triggers:
#   Poll SCM:
#     Schedule: */5 * * * *
#
# Build:
#   Execute shell:
#     Command: sh dist/ci/obs_common.sh
#
# Post Build Actions:
#   Archive the artifacts:
#     Files to archive: **/*
#     Discard all but the last successful/stable artifact to save disk space: 1
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

echo "Setup backend configuration"
# Fix BSConfig.pm.template, this is used by 'src/api/script/start_test_backend'
sed -i -e "s|my \$hostname = .*$|my \$hostname = 'localhost';|" \
       -e "s|our \$bsuser = 'obsrun';|our \$bsuser = 'jenkins';|" \
       -e "s|our \$bsgroup = 'obsrun';|our \$bsgroup = 'jenkins';|" src/backend/BSConfig.pm.template
cp src/backend/BSConfig.pm.template src/backend/BSConfig.pm
