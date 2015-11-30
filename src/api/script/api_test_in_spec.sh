#!/bin/bash -e

BASE_DIR=$PWD
TEMP_DIR=$BASE_DIR/tmp
MYSQL_BASEDIR=$TEMP_DIR/mysql/
MYSQL_DATADIR=$MYSQL_BASEDIR/data
MYSQL_SOCKET=$MYSQL_BASEDIR/mysql.socket
MEMCACHED_PID_FILE=$TEMP_DIR/memcached.pid

MYSQLD_USER=`whoami`
if [[ $EUID == 0 ]];then
  MYSQLD_USER=mysql
  MEMCACHED_USER="-u memcached"
fi

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
bundle exec rake db:create || exit 1
xzcat test/dump_2.5.sql.xz | mysql  -u root --socket=$MYSQL_SOCKET
bundle exec rake db:migrate db:drop || exit 1

# entire test suite
export RAILS_ENV=test
bundle exec rake db:create db:setup || exit 1
mv log/test.log{,.old}
if ! bundle exec rake test:api test:webui ; then
  cat log/test.log
  kill $( cat $MEMCACHED_PID_FILE )
  exit 1
fi

kill $(cat $MEMCACHED_PID_FILE) || :

#cleanup
/usr/bin/mysqladmin -u root --socket=$MYSQL_SOCKET shutdown || true
rm -rf $MYSQL_DATADIR $MYSQL_SOCKET

exit 0
