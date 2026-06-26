#!/bin/bash

set -e

source ./mysql_environment

# entire test suite
export RAILS_ENV=test
bin/rake db:setup

bin/rails assets:precompile

rm -f log/test.log
bin/rake test:api test:spider

#cleanup
/usr/bin/mysqladmin -u $MYSQLD_USER --socket=$MYSQL_SOCKET shutdown || true
rm -rf $MYSQL_DATADIR $MYSQL_SOCKET_DIR

exit 0
