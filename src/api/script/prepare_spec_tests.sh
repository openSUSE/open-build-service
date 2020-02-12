#!/bin/bash -e

### define some variables
BASE_DIR=$PWD
TEMP_DIR=$BASE_DIR/tmp
MYSQL_BASEDIR=$TEMP_DIR/mysql/
MYSQL_DATADIR=$MYSQL_BASEDIR/data
MYSQL_SOCKET_DIR=`mktemp -d`
MYSQL_SOCKET=$MYSQL_SOCKET_DIR/mysql.socket

MYSQLD_USER=`whoami`
if [[ $EUID == 0 ]];then
  MYSQLD_USER=mysql
fi

MYSQL_SERVER=
for dir in /usr/bin /usr/sbin /usr/libexec; do
  if [ -x "$dir/mysqld" ]; then
    MYSQL_SERVER="$dir/mysqld"
    break
  fi
done
if [ -z "$MYSQL_SERVER" ]; then
  echo mysqld not found >&2
  exit 1
fi


### do testing now

rm -rf $MYSQL_DATADIR $MYSQL_SOCKET
mkdir -p $MYSQL_BASEDIR
chown -R $MYSQLD_USER $MYSQL_BASEDIR
mysql_install_db --user=$MYSQLD_USER --datadir=$MYSQL_DATADIR
$MYSQL_SERVER --user=$MYSQLD_USER --datadir=$MYSQL_DATADIR --skip-networking --socket=$MYSQL_SOCKET --pid-file=$TEMP_DIR/mysqld.pid &
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
  encoding: utf8mb4
  socket:   $MYSQL_SOCKET
test:
  adapter:  mysql2
  host:     localhost
  database: api_test
  username: root
  encoding: utf8mb4
  socket:   $MYSQL_SOCKET
  # disable timeout, required on SLES 11 SP3 at least
  connect_timeout:

EOF

echo "MYSQL_BASEDIR=$MYSQL_BASEDIR" > mysql_environment
echo "MYSQL_SOCKET_DIR=$MYSQL_SOCKET_DIR" >> mysql_environment
echo "MYSQL_SOCKET=$MYSQL_SOCKET" >> mysql_environment

