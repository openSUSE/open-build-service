#!/bin/bash -e

### define some variables
BASE_DIR=$PWD
TEMP_DIR=$BASE_DIR/tmp
MYSQL_BASEDIR=$TEMP_DIR/mysql/
MYSQL_DATADIR=$MYSQL_BASEDIR/data
MEMCACHED_PID_FILE=$TEMP_DIR/memcached.pid
MYSQL_SOCKET_DIR=`mktemp -d`
MYSQL_SOCKET=$MYSQL_SOCKET_DIR/mysql.socket

MYSQLD_USER=`whoami`
if [[ $EUID == 0 ]];then
  MYSQLD_USER=mysql
  MEMCACHED_USER="-u memcached"
fi

### define some function
kill_memcached() {
  if [[ -f  $MEMCACHED_PID_FILE ]];then
    MEMCACHED_PID=$(cat $MEMCACHED_PID_FILE)
    if [[ $MEMCACHED_PID ]];then
      kill  $MEMCACHED_PID;
    fi
  fi
}

### do testing now

rm -rf $MYSQL_DATADIR $MYSQL_SOCKET
mkdir -p $MYSQL_BASEDIR
chown -R $MYSQLD_USER $MYSQL_BASEDIR
mysql_install_db --user=$MYSQLD_USER --datadir=$MYSQL_DATADIR
/usr/sbin/mysqld --user=$MYSQLD_USER --datadir=$MYSQL_DATADIR --skip-networking --socket=$MYSQL_SOCKET &
sleep 2

##################### api

# setup files
cp config/options.yml{.example,}
cp config/thinking_sphinx.yml{.example,}
touch config/test.sphinx.conf
cat > config/database.yml <<EOF
development:
  adapter:  mysql2
  host:     localhost
  database: api_25
  username: root
  encoding: utf8
  socket:   $MYSQL_SOCKET
test:
  adapter:  mysql2
  host:     localhost
  database: api_test
  username: root
  encoding: utf8
  socket:   $MYSQL_SOCKET
  # disable timeout, required on SLES 11 SP3 at least
  connect_timeout:

EOF

/usr/sbin/memcached $MEMCACHED_USER -l 127.0.0.1 -d -P $MEMCACHED_PID_FILE || exit 1
# prepare for migration test
export RAILS_ENV=test
# reformat structure.sql to running mysql/mariadb version
bundle.ruby2.5 exec rake.ruby2.5 db:create || exit 1
echo 'SET foreign_key_checks = 0;' > db/structure.sql.reimport
# only needed for mysql <= 5.6
echo 'SET GLOBAL innodb_file_per_table=1, innodb_file_format=Barracuda, innodb_large_prefix=1;' >> db/structure.sql.reimport
cat db/structure.sql >> db/structure.sql.reimport
cat db/structure.sql.reimport | mysql  -u root --socket=$MYSQL_SOCKET api_test || exit 1
bundle.ruby2.5 exec rails.ruby2.5 db:environment:set db:structure:dump db:drop || exit 1
mv db/structure.sql db/structure.sql.git_reformated

# migration test
export RAILS_ENV=development
bundle.ruby2.5 exec rake.ruby2.5 db:create || exit 1
xzcat test/dump_2.5.sql.xz | mysql  -u root --socket=$MYSQL_SOCKET || exit 1
bundle.ruby2.5 exec rake.ruby2.5 db:migrate:with_data db:structure:dump db:drop || exit 1
./script/compare_structure_sql.sh db/structure.sql.git_reformated db/structure.sql || exit 1

# entire test suite
export RAILS_ENV=test
bundle.ruby2.5 exec rake.ruby2.5 db:create db:setup || exit 1

bundle.ruby2.5 exec rails assets:precompile

for suite in "rake.ruby2.5 test:api" "rake.ruby2.5 test:spider" "rspec"; do
  rm -f log/test.log

  # Configure the frontend<->backend connection settings
  if [ "$suite" = "rspec" ]; then
    perl -pi -e 's/source_host: localhost/source_host: backend/' config/options.yml
    perl -pi -e 's/source_port: 3200/source_port: 5352/' config/options.yml
  else
    perl -pi -e 's/source_host: backend/source_host: localhost/' config/options.yml
    perl -pi -e 's/source_port: 5352/source_port: 3200/' config/options.yml
  fi
  if ! (set -x; bundle.ruby2.5 exec $suite); then
    # dump log only in package builds
    [[ -n "$RPM_BUILD_ROOT" ]] && cat log/test.log
    kill_memcached
    exit 1
  fi
done

kill_memcached

#cleanup
/usr/bin/mysqladmin -u root --socket=$MYSQL_SOCKET shutdown || true
rm -rf $MYSQL_DATADIR $MYSQL_SOCKET_DIR

exit 0
