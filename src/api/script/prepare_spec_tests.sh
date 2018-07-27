#!/bin/bash -e

### define some variables
BASE_DIR=$PWD
TEMP_DIR=$BASE_DIR/tmp
MYSQL_BASEDIR=$TEMP_DIR/mysql/
MYSQL_DATADIR=$MYSQL_BASEDIR/data
MYSQL_SOCKET_DIR=`mktemp -d`
MYSQL_SOCKET=$MYSQL_SOCKET_DIR/mysql.socket
RETRY=1

MYSQLD_USER=`whoami`
if [[ $EUID == 0 ]];then
  MYSQLD_USER=mysql
fi

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

echo "MYSQL_BASEDIR=$MYSQL_BASEDIR" > mysql_environment
echo "MYSQL_SOCKET_DIR=$MYSQL_SOCKET_DIR" >> mysql_environment
echo "MYSQL_SOCKET=$MYSQL_SOCKET" >> mysql_environment

