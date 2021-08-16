#!/bin/bash


###############################################################################
#
# MAIN
#
###############################################################################

export LC_ALL=C
SH_LIBDIR=`dirname $0`
source $SH_LIBDIR/functions.setup-appliance.sh

prepare_os_settings

ENABLE_OPTIONAL_SERVICES=0
ENABLE_FORCEPROJECTKEYS=1
MYSQL_USER=root
MYSQL_PASS=opensuse
PID_FILE=/run/setup-appliance.pid

# package or appliance defaults
if [ -e /etc/sysconfig/obs-server ]; then
  source /etc/sysconfig/obs-server
fi

# Set default directories
apidir=/srv/www/obs/api
backenddir=/srv/obs

# Overwrite directory defaults with settings in
# config file /etc/sysconfig/obs-server
if [ -n "$OBS_BASE_DIR" ]; then
  backenddir="$OBS_BASE_DIR"
fi

logline "Starting "`basename $0`" at "`date`
NON_INTERACTIVE=0

if [ -f $PID_FILE ];then
  APID=`cat $PID_FILE`
  if [ -f /proc/$APID/status ];then
    logline `basename $0`" already running. Exiting!"
    exit 0
  else
    logline `basename $0`" died unexpectedly"
  fi
fi

echo $$ > $PID_FILE

trap "rm -f $PID_FILE" EXIT

while [[ $1 ]];do
  case $1 in
    --non-interactive) NON_INTERACTIVE=1;;
    --setup-only) SETUP_ONLY=1;;
    --enable-optional-services) ENABLE_OPTIONAL_SERVICES=1;;
    --force) OBS_API_AUTOSETUP="yes";;
    --disable-forceprojectkeys) ENABLE_FORCEPROJECTKEYS=0;;
  esac
  shift
done

if [ "$OBS_API_AUTOSETUP" != "yes" ]; then
  echo "OBS API Autosetup is not enabled in sysconfig, skipping!"
  exit 0
fi

[[ $HOME == '' ]] && export HOME=/root

# prepare configuration for obssigner before any other backend service
# is started, because obssigner configuration might affect other services
# too
GPG_KEY_CREATED=0

prepare_obssigner

if [[ $GPG_KEY_CREATED == 1 ]];then
  systemctl reload obssrcserver
  systemctl reload obsrepserver
fi

check_required_backend_services

check_recommended_backend_services

check_optional_backend_services

check_unit $MYSQL_SERVICE.service 1

get_hostname

### In case of the appliance, we never know where we boot up !
OLDFQHOSTNAME="NOTHING"
if [ -e $backenddir/.oldfqhostname ]; then
  OLDFQHOSTNAME=`cat $backenddir/.oldfqhostname`
fi

DETECTED_HOSTNAME_CHANGE=0

if [ "$FQHOSTNAME" != "$OLDFQHOSTNAME" ]; then
  echo "Appliance hostname changed from $OLDFQHOSTNAME to $FQHOSTNAME !"
  DETECTED_HOSTNAME_CHANGE=1

fi

if [[ $DETECTED_HOSTNAME_CHANGE == 1 ]];then
  adapt_worker_jobs
  adjust_api_config
fi

echo "$FQHOSTNAME" > $backenddir/.oldfqhostname

OBSVERSION=`rpm -q --qf '%{VERSION}' obs-server`
if [ -e /etc/os-release ];then
  # execute in subshell to preserve the values of the variables
  # $NAME and $VERSION as these are very generic
  OS_NAME=`. /etc/os-release;echo $NAME`
  OS_VERSION=`. /etc/os-release;echo $VERSION`
  OS="$OS_NAME $OS_VERSION"
else
  OS="UNKNOWN"
fi
RUN_INITIAL_SETUP=""

prepare_database_setup

enable_forceprojectkeys

check_server_key

generate_proposed_dnsnames

DNS_NAMES="$rv"

DETECTED_CERT_CHANGE=0

check_server_cert

import_ca_cert

relink_server_cert

fix_permissions

prepare_apache2

prepare_passenger

check_unit $HTTPD_SERVICE.service

check_unit memcached.service

# make sure that apache gets restarted after cert change
if [[ $DETECTED_CERT_CHANGE && ! $SETUP_ONLY ]];then
    systemctl reload $HTTPD_SERVICE.service
fi

check_unit obs-api-support.target

create_issue_file

if [ -n "$FQHOSTNAME" ]; then
  create_overview_html
  add_login_info_to_issue
else
  network_failure_warning
fi

create_sign_cert

exit 0
