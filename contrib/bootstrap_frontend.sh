#!/bin/bash 

BASEDIR=`dirname $0`
. $BASEDIR/common.sh

allow_vendor_change

add_common_repos

install_common_packages

setup_ruby

install_bundle

setup_database

setup_memcached

configure_app

configure_database

print_final_information

chown_vagrant_owned_dirs

exit 0
