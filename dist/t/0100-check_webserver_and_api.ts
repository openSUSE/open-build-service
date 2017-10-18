#!/bin/bash

export BASH_TAP_ROOT=$(dirname $0)

. $(dirname $0)/bash-tap-bootstrap

plan tests 4

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
HTTP_OK=$(curl -ik https://localhost/apidocs/index 2>/dev/null |grep "200 OK")
[ -n "$HTTP_OK" ]
is $? 0 "Checking for https://localhost/apidocs/index"


STATUS_CODE_200=$(curl -I http://localhost 2>/dev/null|head -1|grep -w 200)
[[ -n $STATUS_CODE_200 ]]
is "$?" 0 "Checking https://localhost for http status code 200"
