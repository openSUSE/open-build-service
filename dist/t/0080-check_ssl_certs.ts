#!/bin/bash

export BOOTSTRAP_TEST_MODE=1
export NON_INTERACTIVE=1
export BASH_TAP_ROOT=$(dirname $0)

. $(dirname $0)/bash-tap-bootstrap

plan tests 5

for i in $(dirname $0)/../setup-appliance.sh /usr/lib/obs/server/setup-appliance.sh;do
	[[ -f $i && -z $SETUP_APPLIANCE ]] && SETUP_APPLIANCE=$i
done

if [[ -z $SETUP_APPLIANCE ]];then
	BAIL_OUT "Could not find setup appliance"
fi

. $SETUP_APPLIANCE

get_hostname
FQHN=$FQHOSTNAME

for file in \
server.crt \
server.key \
server.$FQHN\.created \
server.$FQHN\.crt
do
  [ -e /srv/obs/certs/$file ]
  is "$?" 0 "Checking file $file"
done

curl https://localhost &>/dev/null
is "$?" 0 "Checking https://localhost for SSL Certificate Errors"
