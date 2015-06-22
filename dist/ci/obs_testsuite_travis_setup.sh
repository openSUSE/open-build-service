#! /bin/sh

. `dirname $0`/obs_testsuite_common.sh

setup_git

# travis rvm can not deal with our extended executable names
sed -i 1,1s,\.ruby2\.2,, src/api/{script,bin}/*

setup_api

