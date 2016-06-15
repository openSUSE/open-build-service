#!/bin/bash

export BOOTSTRAP_TEST_MODE=1
export NON_INTERACTIVE=1
export BASH_TAP_ROOT=$(dirname $0)


. $(dirname $0)/bash-tap-bootstrap


if [ -f $(dirname $0)/../setup-appliance.sh ];
then
	. $(dirname $0)/../setup-appliance.sh
else
  if [ -f /usr/lib/obs/server/setup-appliance.sh ];then
	. /usr/lib/obs/server/setup-appliance.sh
  else
    BAIL_OUT "Could not find setup-appliance.sh"
  fi
fi

plan tests 12


################################################################################
# Cleanup temporary files

rm -rf $(dirname $0)/tmp

get_hostname localhost
is "$FQHOSTNAME" "localhost" "Checking FQHOSTNAME without domain"
is "$DOMAINNAME" "" "Checking with empty DOMAINNAME"
is "$SHORTHOSTNAME" "localhost" "Checking SHORTHOSTNAME localhost"

generate_proposed_dnsnames
is "$rv" 'localhost ' "Checking proposed dns names without domain"

get_hostname foobar.suse.de

is "foobar.suse.de" $FQHOSTNAME "Checking FQHOSTNAME "
is "$SHORTHOSTNAME" "foobar" "Checking SHORTHOSTNAME foobar"

generate_proposed_dnsnames
is "$rv" 'foobar foobar.suse.de localhost' "Checking proposed dns names"


# CHECKING CERT TEMPLATE
create_selfsigned_certificate

is "$OPENSSL_CONFIG" 'prompt = no
distinguished_name  = req_distinguished_name

[req_distinguished_name]
countryName = CC
stateOrProvinceName     = OBS Autogen State or Province
localityName            = OBS Autogen Locality
organizationName        = OBS Autogen Organisation
organizationalUnitName  = OBS Autogen Organizational Unit
commonName              = foobar.suse.de
emailAddress            = test@email.address

[req]
req_extensions = v3_req
distinguished_name  = req_distinguished_name
attributes    = req_attributes
x509_extensions = v3_ca

[req_attributes]

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment

[ v3_ca ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = CA:true

[ v3_req ]

# Extensions to add to a certificate request

basicConstraints = critical,CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]

DNS.0 = foobar
DNS.1 = foobar.suse.de
DNS.2 = localhost


[ v3_ca ]
basicConstraints = CA:TRUE
subjectAltName = @alt_names

'

export backenddir=$(dirname $0)/tmp/

mkdir -p $backenddir/certs

check_server_key
key_file=$backenddir\certs/server.key
[ -e $key_file ]
is 0 $? "Checking if key file ($key_file) exists"

check_server_cert

for ext in crt created
do
  file=server.foobar.suse.de.$ext;
  [ -e $backenddir/certs/$file ]
  is $? 0 "Checking file $file"
done

relink_server_cert

SUBJ=$(openssl x509 -text -noout -in $backenddir/certs/server.crt |grep DNS)

is \
  "$SUBJ" \
  '                DNS:foobar, DNS:foobar.suse.de, DNS:localhost'\
  "Checking openssl certificate subject" 
