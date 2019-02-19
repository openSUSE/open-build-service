#!/bin/bash

set -e

source ./mysql_environment

# migration test
export RAILS_ENV=development
bin/rake db:create || exit 1
mv db/structure.sql db/structure.sql.git
xzcat test/dump_2.5.sql.xz | mysql  -u root --socket=$MYSQL_SOCKET
bin/rake db:migrate:with_data db:structure:dump db:drop
./script/compare_structure_sql.sh db/structure.sql.git db/structure.sql

# entire test suite
export RAILS_ENV=test
bin/rake db:create db:setup

bin/rails assets:precompile

rm -f log/test.log
bin/rake test:api test:spider

#cleanup
/usr/bin/mysqladmin -u root --socket=$MYSQL_SOCKET shutdown || true
rm -rf $MYSQL_DATADIR $MYSQL_SOCKET_DIR

exit 0
