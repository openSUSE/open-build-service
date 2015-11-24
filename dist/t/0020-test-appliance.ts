#!/bin/bash

export BOOTSTRAP_TEST_MODE=1
export NON_INTERACTIVE=1
export BASH_TAP_ROOT=$(dirname $0)

. $(dirname $0)/bash-tap-bootstrap

plan tests 23

# Service enabled and started
for srv in \
obsapidelayed \
obsdispatcher \
obspublisher \
obsrepserver \
obsscheduler \
obssrcserver \
apache2 \
mysql
do
  STATE=` systemctl is-enabled $srv\.service 2>/dev/null`
  is "$STATE" "enabled" "Checking $srv enabled"
  ACTIVE=`systemctl is-active $srv\.service`
  is "$ACTIVE" "active" "Checking $srv status"
done


FQHN=$(hostname -f)
for file in \
server.crt \
server.key \
server.$FQHN\.created \
server.$FQHN\.crt
do
  [ -e /srv/obs/certs/$file ]
  is "$?" 0 "Checking file $file"
done

DB_NAME=api_production
DB_EXISTS=$(mysql -e "show databases"|grep $DB_NAME)
is "$DB_EXISTS" "$DB_NAME" "Checking if database exists"

TABLES_IN_DB=$(mysql -e "show tables" $DB_NAME)
[[ $TABLES_IN_DB ]]
is "$?" 0 "Checking if tables in database $DB_NAME"

curl https://localhost &>/dev/null
is "$?" 0 "Checking https://localhost for SSL Certificate Errors"
