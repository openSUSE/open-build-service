#!/bin/bash

export BOOTSTRAP_TEST_MODE=1
export NON_INTERACTIVE=1
export BASH_TAP_ROOT=$(dirname $0)

. $(dirname $0)/bash-tap-bootstrap

plan tests 27

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

STATUS_CODE_200=$(curl -I http://localhost 2>/dev/null|head -1|grep -w 200)
[[ -n $STATUS_CODE_200 ]]
is "$?" 0 "Checking https://localhost for http status code 200"

if [ ! -f $HOME/.oscrc ];then
	
	cat <<EOF > $HOME/.oscrc

[general]
apiurl = https://localhost
[https://localhost]
user = Admin
pass = opensuse

EOF

fi

API_VERSION=$(osc api about|grep revision|perl -p -e 's#.*<revision>(.*)</revision>.*#$1#')
RPM_VERSION=$(rpm -q --qf "%{version}\n" obs-server)

is $API_VERSION $RPM_VERSION "Checking api about version"

OSC_UNAUHTORIZED=$(osc -A https://localhost ls 2>&1|grep 401)
[ -z "$OSC_UNAUHTORIZED" ]
is "$?" 0 "Checking authorization for osc"

# test /apidocs
HTTP_OK=$(curl -ik https://localhost/apidocs/ 2>/dev/null |grep "200 OK")
[ -n "$HTTP_OK" ]
is $? 0 "Checking for https://localhost/apidocs/"


