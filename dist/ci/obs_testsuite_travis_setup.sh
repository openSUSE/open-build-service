#! /bin/sh

. `dirname $0`/obs_testsuite_common.sh

# create versioned links for travis
ln -s ruby /usr/bin/ruby.ruby2.2
ln -s rake /usr/bin/rake.ruby2.2

setup_git
setup_api

