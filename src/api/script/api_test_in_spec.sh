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
migrate:
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

# migration test
export RAILS_ENV=migrate
bundle.ruby2.4 exec rake.ruby2.4 db:create || exit 1
xzcat test/dump_2.5.sql.xz | mysql  -u root --socket=$MYSQL_SOCKET
bundle.ruby2.4 exec rake.ruby2.4 db:migrate db:structure:dump db:drop || exit 1
if test `diff db/structure.sql{.git,} | wc -l` -gt 0 ; then
  echo "ERROR: Migration is producing a different structure.sql"
  diff -u db/structure.sql{,.git}
  exit 1
fi

# entire test suite
export RAILS_ENV=test
bundle.ruby2.4 exec rake.ruby2.4 db:create db:setup || exit 1

for suite in "rake.ruby2.4 test:api" "rake.ruby2.4 test:webui" "rake.ruby2.4 test:spider" "rspec.ruby2.4"; do
  rm -f log/test.log
  bundle.ruby2.4 exec rails assets:precompile
  if ! bundle.ruby2.4 exec $suite; then
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
