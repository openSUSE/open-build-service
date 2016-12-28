#!/bin/bash 

BASEDIR=`dirname $0`
. $BASEDIR/common.sh

allow_vendor_change

add_common_repos

install_common_packages

setup_ruby

install_bundle

configure_app

setup_mariadb

setup_memcached

configure_database

print_final_information

setup_data_dir

chown_vagrant_owned_dirs

setup_kerberos_server

exit 0
