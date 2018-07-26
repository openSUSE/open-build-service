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

# migration test
export RAILS_ENV=development
bin/rake db:create || exit 1
mv db/structure.sql db/structure.sql.git
xzcat test/dump_2.5.sql.xz | mysql  -u root --socket=$MYSQL_SOCKET || exit 1
bin/rake db:migrate:with_data db:structure:dump db:drop || exit 1
./script/compare_structure_sql.sh db/structure.sql.git db/structure.sql || exit 1

# entire test suite
export RAILS_ENV=test
bin/rake db:create db:setup || exit 1

bin/rails assets:precompile

for suite in "rake test:api" "rake test:spider" "rspec"; do
  rm -f log/test.log

  # Configure the frontend<->backend connection settings
  if [ "$suite" = "rspec" ]; then
    perl -pi -e 's/source_host: localhost/source_host: backend/' config/options.yml
    perl -pi -e 's/source_port: 3200/source_port: 5352/' config/options.yml
  else
    perl -pi -e 's/source_host: backend/source_host: localhost/' config/options.yml
    perl -pi -e 's/source_port: 5352/source_port: 3200/' config/options.yml
  fi
  bin/$suite
done

#cleanup
/usr/bin/mysqladmin -u root --socket=$MYSQL_SOCKET shutdown || true
rm -rf $MYSQL_DATADIR $MYSQL_SOCKET_DIR

exit 0
