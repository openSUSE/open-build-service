#!/bin/bash 

BASEDIR=`dirname $0`
. $BASEDIR/common.sh

allow_vendor_change

add_common_repos

install_common_packages

setup_ruby

setup_ruby_gem

install_bundle

configure_app

setup_mariadb

setup_memcached

setup_signd

configure_database

configure_search

print_final_information

setup_data_dir

chown_vagrant_owned_dirs

exit 0
