#!/bin/bash

cat <<eof > /etc/krb5.conf
[libdefaults]
  default_realm = EXAMPLE.COM
  default_keytab_name = FILE:/etc/krb5.keytab
[realms]
  EXAMPLE.COM = {
    kdc = krb.example.com
    admin_server = krb.example.com
  }
eof

printf "%s\n%s\n%s\n" >> /etc/hosts \
  "127.0.0.1 krb.example.com" \
  "127.0.0.1 www.example.com" \
  "127.0.0.1 $(hostname)"

mkdir -p /etc/krb5kdc

cat <<eof > /etc/krb5kdc/kdc.conf
[kdcdefaults]
  kdc_listen = 88
  kdc_tcp_listen = 88
[realms]
  EXAMPLE.COM = {
    kadmind_port = 749
    max_life = 12h 0m 0s
    max_renewable_life = 7d 0h 0m 0s
    master_key_type = aes128-cts
    supported_enctypes = aes128-cts:normal
  }
[logging]
  kdc = FILE:/var/log/krb5kdc.log
  admin_server = FILE:/var/log/kadmin.log
  default = FILE:/var/log/krb5lib.log
eof

# Not enough entropy on virtual machines...
printf "\n\n" | /usr/sbin/kdb5_util create -r EXAMPLE.COM -s
#tar -vzcf dist/ci/krb5kdc-test-data.tgz /var/lib/kerberos/krb5kdc
#tar -zxf dist/ci/krb5kdc-test-data.tgz -C /

[ ! -d "/run/user/0" ] && mkdir -p "/run/user/0"

printf "%s\n" \
    "addprinc -randkey HTTP/www.example.com@EXAMPLE.COM" \
    "addprinc -randkey HTTP/localhost@EXAMPLE.COM" \
    "addprinc -pw tnert trent@EXAMPLE.COM" \
    "ktadd HTTP/www.example.com@EXAMPLE.COM" \
    "ktadd HTTP/localhost@EXAMPLE.COM" \
  | /usr/sbin/kadmin.local

service krb5-kdc start
service krb5-admin-server start

chmod 755 /etc/krb5.keytab
