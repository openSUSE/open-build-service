#!/bin/bash

###############################################################################
#
# DEFINITION OF FUNCTIIONS
#
###############################################################################
function execute_silently {
  $@ > /dev/null 2>&1
  return $?
}
###############################################################################
function logline {
  [[ $BOOTSTRAP_TEST_MODE == 1 ]] && return
  echo $@
}
###############################################################################
function check_unit {
  srv=$1
  service_critical=$2

  [[ $SETUP_ONLY == 1 ]] && return

  echo "Checking unit $srv ..."
  IS_ENABLED=`systemctl is-enabled $srv`
  if [ "$IS_ENABLED" != "enabled" ];then
    logline "Enabling $srv"
    execute_silently systemctl enable --now $srv
  fi
  if [[ $? -gt 0 ]];then
    logline "WARNING: Enabling $srv daemon failed."
  fi

  STATUS=`systemctl is-active $srv 2>/dev/null`
  if [[ "$STATUS" == "inactive" ]];then
    echo "$srv daemon not started. Trying to start"
    execute_silently systemctl start $srv
    if [[ $? -gt 0 ]];then
      echo -n "Starting $srv daemon failed."
      if [[ $service_critical == 1 ]];then
        echo " Exiting ..."
        exit 1
      fi
    fi
  fi

}
###############################################################################
function check_server_cert {
  # Create directory if not exists
  # Usefull on testing systems where no obs-server rpm is installed
  [ -d $backenddir/certs/ ] || mkdir -p $backenddir/certs/
  if [[ ! -e $backenddir/certs/server.${FQHOSTNAME}.created || ! -e $backenddir/certs/server.${FQHOSTNAME}.crt ]]; then
    # setup ssl certificates (NOT protected with a passphrase)
    logline "Creating a default SSL certificate for the server"
    logline "Please replace it with your version in $backenddir/certs directory..."
    DETECTED_CERT_CHANGE=1
    # hostname specific certs - survive intermediate hostname changes
    if [ ! -e $backenddir/certs/server.${FQHOSTNAME}.crt ] ; then
      # This is just a dummy SSL certificate, but it has a valid hostname.
      # Admin can replace it with his version.
      create_selfsigned_certificate
      echo "$OPENSSL_CONFIG" | openssl req -new -nodes -config /dev/stdin \
          -x509 -days 365 -batch \
          -key $backenddir/certs/server.key \
          -out $backenddir/certs/server.${FQHOSTNAME}.crt

      if [[ $? == 0 ]];then
        echo "Do not remove this file or new SSL CAs will get created." > $backenddir/certs/server.${FQHOSTNAME}.created
      fi
    else
      echo "ERROR: SSL CAs in $backenddir/certs exists, but were not created for your hostname"
      exit 1
    fi
  fi
}
###############################################################################
function create_selfsigned_certificate() {

  cert_outdir=$backenddir/certs
  COUNTER=0
  DNS_NAMES=""
  for name in $PROPOSED_DNS_NAMES;do
    DNS_NAMES="$DNS_NAMES
DNS.$COUNTER = $name"
    COUNTER=$(($COUNTER + 1 ))
  done

  logline "Creating crt/key in $cert_outdir"
  OPENSSL_CONFIG="prompt = no
distinguished_name  = req_distinguished_name

[req_distinguished_name]
countryName = CC
stateOrProvinceName     = OBS Autogen State or Province
localityName            = OBS Autogen Locality
organizationName        = OBS Autogen Organisation
organizationalUnitName  = OBS Autogen Organizational Unit
commonName              = $FQHOSTNAME
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
$DNS_NAMES


[ v3_ca ]
basicConstraints = CA:TRUE
subjectAltName = @alt_names

"

}
###############################################################################
function get_hostname {

  if [[ $1 && $BOOTSTRAP_TEST_MODE == 1 ]];then
    FQHOSTNAME=$1
  else
    TIMEOUT=30
    while [ -z "$FQHOSTNAME" -o "$FQHOSTNAME" = "localhost" ];do
      # Try to get the FQHN via hostname
      HN=`hostname -f 2>/dev/null`
      if [[ $HN =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]];then
        FQHOSTNAME=$HN
      fi
      TIMEOUT=$(($TIMEOUT-1))
      [ "$TIMEOUT" -le 0 ] && break
      echo "Waiting for FQHOSTNAME ($TIMEOUT)"
      sleep 1
    done
    if [ -z "$FQHOSTNAME" -o "$FQHOSTNAME" = "localhost" ] && [ -x "$(command -v hostnamectl)" ];then
      FQHOSTNAME=`hostnamectl --static 2>/dev/null`
    fi
    if [ -z "$FQHOSTNAME" -o "$FQHOSTNAME" = "localhost" -a -s /etc/hostname ];then
      FQHOSTNAME=`cat /etc/hostname`
    fi
  fi

  if type -p ec2-public-hostname; then
    FQHOSTNAME=`ec2-public-hostname`
  fi

  if [ "$FQHOSTNAME" = "" ]; then
    ask "Please enter the full qualified hostname!"
    FQHOSTNAME=$rv
  fi

  # fallback in non-interative mode
  if [ "$FQHOSTNAME" = "" ]; then
    # Prefer interface with default route if exists
    DEFAULT_ROUTE_INTERFACE=`LANG=C ip route show|perl  -e '$_=<>; ( m/^default via.*dev\s+([\w]+)\s.*/ ) && print $1'`
    # Fallback to IP of the VM/host
    FQHOSTNAME=`LANG=C ip addr show $DEFAULT_ROUTE_INTERFACE| perl -lne '( m#^\s+inet\s+([0-9\.]+)(/\d+)?\s+.*# ) && print $1' | grep -v ^127. | head -n 1`
    if [ "$?" != "0" -o "$FQHOSTNAME" = "" ]; then
      echo "    Can't determine hostname or IP - Network setup failed!"
      echo "    Check if networking is up and dhcp is working!"
      echo "    Using 'localhost' as FQHOSTNAME."
      FQHOSTNAME="localhost"
    fi
    USEIP=$FQHOSTNAME
  fi

  if [[ -z $USEIP  ]];then
    DOMAINNAME=""
    if [[ $FQHOSTNAME =~ '.' ]];then
      DOMAINNAME=$(echo $FQHOSTNAME | perl -pe 's/^[\w\-_]*\.(.*)/$1/')
      SHORTHOSTNAME=$(echo $FQHOSTNAME | perl -pe 's/^([\w\-_]*)\..*/$1/')
    else
      SHORTHOSTNAME=$FQHOSTNAME
    fi
  fi
}
###############################################################################
function generate_proposed_dnsnames {
  if [[ ! $FQHOSTNAME ]];then
    get_hostname
  fi

  if [[ $FQHOSTNAME != 'localhost' ]];then
    LOCAL_HOST="localhost"
  fi

  if [[ $FQHOSTNAME == $SHORTHOSTNAME ]];then
    DNSNAMES="$SHORTHOSTNAME $LOCAL_HOST"
  else
    DNSNAMES="$SHORTHOSTNAME $FQHOSTNAME $LOCAL_HOST"
  fi
  ask "Proposed DNS names: " "$DNSNAMES"

  PROPOSED_DNS_NAMES=$rv
}
###############################################################################
function adjust_api_config {

      echo "Adjust configuration for this hostname"
      # use local host to avoid SSL verification between webui and api

      api_options_yml=$apidir/config/options.yml
      sed -i 's,^frontend_host: .*,frontend_host: "localhost",' $api_options_yml
      sed -i 's,^frontend_port: .*,frontend_port: 443,' $api_options_yml
      sed -i 's,^frontend_protocol: .*,frontend_protocol: "'"https"'",' $api_options_yml

}
###############################################################################
function adapt_worker_jobs {
  #changed IP means also that leftover jobs are invalid - cope with that
  echo "Adapting present worker jobs"
  sed -i "s,server=\"http://[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:5352,server=\"http://$FQHOSTNAME:5352,g" \
    $backenddir/jobs/*/* 2> /dev/null
  sed -i "s,server=\"http://[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:5252,server=\"http://$FQHOSTNAME:5252,g" \
    $backenddir/jobs/*/* 2> /dev/null
  #remove old workers status and idling/building markers
  rm -f $backenddir/jobs/*/*status 2> /dev/null
  rm -f $backenddir/workers/*/* 2> /dev/null
  # create repo directory or apache fails when nothing got published
  mkdir -p $backenddir/repos
  chown obsrun:obsrun $backenddir/repos
}
###############################################################################
function prepare_database_setup {

  cd $apidir
  RAILS_ENV=production bin/rails db:migrate:status > /dev/null 2>&1

  if [[ $? > 0 ]];then
    echo "Initialize MySQL databases (first time only)"
    DATADIR_FILE=$(grep datadir -rl /etc/my.cnf*)
    echo " - reconfiguring datadir in $DATADIR_FILE"
    sed -i -E '0,/(#\s*)?datadir/ s!#\s*datadir\s*=\s*/var/lib/mysql$!datadir = /srv/obs/MySQL!' $DATADIR_FILE
    echo " - installing to new datadir"
    mysql_install_db
    echo " - changing ownership for new datadir"
    chown mysql:mysql -R /srv/obs/MySQL
    MYSQL_LOG=$(grep log-error /etc/my.cnf.d/*.cnf|perl -p -e 's/.*:log-error=(.*)/$1/')
    if [ -n "$MYSQL_LOG" ];then
      echo " - prepare log file $MYSQL_LOG"
      LOG_DIR=`dirname $MYSQL_LOG`
      if [ ! -d $LOG_DIR ];then
        mkdir -p $LOG_DIR
        chown mysql:mysql $LOG_DIR
      fi
      touch $MYSQL_LOG
      chown mysql:mysql $MYSQL_LOG
    fi
    echo " - restarting mysql"
    systemctl restart $MYSQL_SERVICE
    echo " - setting new password for user root in mysql"
    mysqladmin -u $MYSQL_USER password $MYSQL_PASS
    if [[ $? > 0 ]];then
      echo "ERROR: Your mysql setup doesn't fit your rails setup"
      echo "Please check your database settings for mysql and rails"
      exit 1
    fi
    RUN_INITIAL_SETUP="true"
  fi

  RAKE_COMMANDS=""

  if [ -n "$RUN_INITIAL_SETUP" ]; then
    logline "Initialize OBS api database (first time only)"
    cd $apidir
    RAKE_COMMANDS="db:setup writeconfiguration"
  else
    logline "Migrate OBS api database"
    cd $apidir
    RAKE_COMMANDS="db:migrate:with_data"
    echo
  fi

  logline "Setting ownership of '$backenddir' obsrun"
  chown obsrun:obsrun $backenddir

  logline "Setting up rails environment"
  for cmd in $RAKE_COMMANDS
  do
    logline " - Doing 'rails $cmd'"
    RAILS_ENV=production SAFETY_ASSURED=1 bin/rails $cmd >> $apidir/log/db_migrate.log 2>&1
    if [[ $? > 0 ]];then
      (>&2 echo "Command $cmd FAILED")
      exit 1
    fi
  done

  if [ -n "$RUN_INITIAL_SETUP" ]; then
    if [[ ! "$SETUP_ONLY" ]];then
      `systemctl restart obsscheduler.service`
    fi
  fi
}

###############################################################################
function add_login_info_to_issue {

  cat >> /etc/issue <<EOF

Connect to the web interface via:     https://$FQHOSTNAME
Connect to the api interface via:     https://$FQHOSTNAME
Browse the build packages via:        http://$FQHOSTNAME:82

* "Admin"/"root" user password is "opensuse" by default.
* Connect to the web interface now to finish the OBS setup.

More informations about this appliance are available here:

http://en.opensuse.org/Build_Service/OBS-Appliance

                              Greetings from the Open Build Service Team
                              http://www.open-build-service.org

EOF

}

###############################################################################
function network_failure_warning {

  echo "OBS appliance could not get setup, no network found" > /srv/www/obs/overview/index.html

  cat <<EOF > /etc/issue
*******************************************************************************
**           NETWORK SETUP FAILED                                            **
**                                                                           **
** OBS is not usable. A working DNS resolution for your host is required!    **
** You can check this with 'hostname -f'.                                    **
** This often happens in virtualization environments like e.g. VirtualBox.   **
**                                                                           **
** You also could run                                                        **
**                                                                           **
** /usr/lib/obs/server/setup-appliance.sh                                    **
**                                                                           **
** for interactive configuration                                             **
**                                                                           **
*******************************************************************************
EOF


}
###############################################################################
function check_server_key {
  # reuse signing key even if hostname changed
  if [ ! -e $backenddir/certs/server.key ]; then
      logline "Creating $backenddir/certs/server.key"
      install -d -m 0700 $backenddir/certs
      openssl genrsa -out $backenddir/certs/server.key 4096 2>/dev/null
  else
      logline "Found $backenddir/certs/server.key"
  fi
}
###############################################################################
function import_ca_cert {
  # apache has to trust the api ssl certificate
  if [ ! -e /etc/ssl/certs/server.${FQHOSTNAME}.crt ]; then
    cp $backenddir/certs/server.${FQHOSTNAME}.crt \
      ${TRUST_ANCHORS_DIR}/server.${FQHOSTNAME}.pem
    $UPDATE_SSL_TRUST_BIN
  fi
}
###############################################################################
function relink_server_cert {

  if [[ $DETECTED_CERT_CHANGE == 1 ]];then
    CERT_LINK_FILE=$backenddir/certs/server.crt
    # check if CERT_LINK_FILE not exists or is symbolic link because we don't
    # want to remove real files
    if [ ! -e $CERT_LINK_FILE -o -L $CERT_LINK_FILE ];then
      # change links for certs according to hostnames
      cd $backenddir/certs
      rm -f server.crt
      ln -sf server.${FQHOSTNAME}.crt server.crt
      cd - >/dev/null
    fi
  fi
}

###############################################################################
function fix_permissions {
  cd $apidir
  chown -R $HTTPD_USER:$HTTPD_GROUP $apidir/log
}

###############################################################################
function create_issue_file {
  echo "Recreating /etc/issue"
  # create base version of /etc/issues
  cat > /etc/issue <<EOF
Welcome to Open Build Service(OBS) Appliance $OBSVERSION
based on $OS

EOF

  # check if signing packages is enabled, otherwise add warning to /etc/issue
  if ! grep -q "^our \$sign =" /usr/lib/obs/server/BSConfig.pm ; then
    echo "Adding signing hint to /etc/issue"
    cat >> /etc/issue <<EOF

WARNING: **** Package signing is disabled, maybe due to lack of hardware number generator ****

EOF
  fi

}

###############################################################################
function create_overview_html {
  echo "Creating overview.html"
  sed -e "s,___API_URL___,https://$FQHOSTNAME,g" \
      -e "s,___REPO_URL___,http://$FQHOSTNAME:82,g" \
      /srv/www/obs/overview/overview.html.TEMPLATE > /srv/www/obs/overview/index.html
}
###############################################################################

function ask {
  logline $1
  if [[ $NON_INTERACTIVE == 1 ]];then
    rv=$2
    logline "Using default value '$rv' in non-interactive mode"
    return
  fi

  echo "Default: $2"
  read rv

  if [[ ! $rv ]];then
    rv=$2
  fi

}
###############################################################################
function check_required_backend_services {

  [[ $SETUP_ONLY == 1 ]] && return
  REQUIRED_SERVICES="obsrepserver obssrcserver obsscheduler obsdispatcher obspublisher"

  for srv in $REQUIRED_SERVICES ;do
    ENABLED=`systemctl is-enabled $srv`
    [[ "$ENABLED" == "enabled" ]] || systemctl enable --now $srv
    ACTIVE=`systemctl is-active $srv`
    [[ "$ACTIVE" == "active" ]] || systemctl start $srv
  done

}
###############################################################################
function check_recommended_backend_services {

  [[ $SETUP_ONLY == 1 ]] && return

  RECOMMENDED_SERVICES="obsdodup obsdeltastore obssigner $OBS_SIGND obsservicedispatch"

  for srv in $RECOMMENDED_SERVICES;do
    STATE=$(systemctl is-enabled $srv)
    if [ $STATE != "enabled" ];then
      ask "Service $srv is not enabled. Would you like to enable it? [Yn]" "y"
      case $rv in
        y|yes|Y|YES)
          logline "Recommended service $srv enabled now!"
          systemctl enable --now $srv
        ;;
      esac
    else
      logline "Recommended service $srv already enabled!"
    fi
  done
}
###############################################################################
function check_optional_backend_services {

  DEFAULT_ANSWER="n"

  if [[ $ENABLE_OPTIONAL_SERVICES ]];then
    DEFAULT_ANSWER="y"
  fi

  [[ $SETUP_ONLY == 1 ]] && return
  OPTIONAL_SERVICES="obswarden obsapisetup obsstoragesetup obsworker obsservice obssourcepublish"

  for srv in $OPTIONAL_SERVICES;do
    STATE=$(systemctl is-enabled $srv)
    if [ $STATE != "enabled" ];then
      ask "Service $srv is not enabled. Would you like to enable it? [yN]" $DEFAULT_ANSWER
      case $rv in
        y|yes|Y|YES)
          systemctl enable --now $srv
        ;;
      esac
    else
      logline "Optional service $srv already enabled!"
    fi
  done
}
###############################################################################
function prepare_apache2 {

  [[ $SETUP_ONLY == 1 ]] && return

  PKG2INST=""
  for pkg in $APACHE_ADDITIONAL_PACKAGES;do
    rpm -q $pkg >/dev/null || PKG2INST="$PKG2INST $pkg"
  done

  if [[ -n $PKG2INST ]];then
    $INST_PACKAGES_CMD $PKG2INST >/dev/null
  fi

  if [ "$CONFIGURE_APACHE" == 1 ];then
    MODULES="passenger rewrite proxy proxy_http headers socache_shmcb xforward"

    for mod in $MODULES;do
      a2enmod -q $mod || a2enmod $mod
    done

    FLAGS=SSL

    for flag in $FLAGS;do
      a2enflag $flag >/dev/null
    done
  fi

}
###############################################################################
function prepare_passenger {

  perl -p -i -e \
    's#^(\s*)PassengerRuby "/usr/bin/ruby"#$1\PassengerRuby "/usr/bin/ruby.ruby3.4"#' \
      $MOD_PASSENGER_CONF

}
###############################################################################
function prepare_obssigner {

  # Only used if there is a local BSConfig
  if [ -e /usr/lib/obs/server/BSConfig.pm ]; then
    # signing setup
    perl -p -i -e 's,^\s*#\s*our \$gpg_standard_key.*,our \$gpg_standard_key = "/srv/obs/obs-default-gpg.asc";,' /usr/lib/obs/server/BSConfig.pm
    perl -p -i -e 's,^\s*#\s*our \$keyfile.*,our \$keyfile = "/srv/obs/obs-default-gpg.asc";,' /usr/lib/obs/server/BSConfig.pm
    perl -p -i -e 's,^\s*#\s*our \$sign = .*,our \$sign = "/usr/bin/sign";,' /usr/lib/obs/server/BSConfig.pm
    chmod 4755 /usr/bin/sign

    # create default gpg key if not existing
    if [ ! -e "$backenddir"/obs-default-gpg.asc ] && grep -q "^our \$keyfile.*/obs-default-gpg.asc.;$" /usr/lib/obs/server/BSConfig.pm; then
      GPG_KEY_CREATED=1
      echo -n Generating OBS default GPG key ....
      mkdir -p "$backenddir"/gnupg/phrases
      chmod -R 0700 "$backenddir"/gnupg
      cat >/tmp/obs-gpg.$$ <<EOF
           %echo Generating a default OBS instance key
           Key-Type: RSA
           Key-Length: 4096
           Subkey-Type: ELG-E
           Subkey-Length: 4096
           Name-Real: private OBS
           Name-Comment: key without passphrase
           Name-Email: defaultkey@localobs
           Expire-Date: 30y
           %no-protection
           %commit
           %echo done
EOF
      gpg2 --homedir $backenddir/gnupg --batch --gen-key /tmp/obs-gpg.$$
      gpg2 --homedir $backenddir/gnupg --export -a > "$backenddir"/obs-default-gpg.asc
      rm /tmp/obs-gpg.$$
      # empty file just for accepting the key
      touch "$backenddir/gnupg/phrases/defaultkey@localobs"
    fi
    # to update sign.conf also after an appliance update
    if [ -e "$backenddir"/obs-default-gpg.asc ] && ! grep -q "^user" /etc/sign.conf; then
      logline "Configuring /etc/sign.conf"
      # extend signd config
      echo "user: defaultkey@localobs"   >> /etc/sign.conf
      echo "server: 127.0.0.1"           >> /etc/sign.conf
      echo "allowuser: obsrun"           >> /etc/sign.conf
      echo "allow: 127.0.0.1"            >> /etc/sign.conf
      echo "phrases: $backenddir/gnupg/phrases" >> /etc/sign.conf
      echo done
      sed -i 's,^# \(our $sign =.*\),\1,' /usr/lib/obs/server/BSConfig.pm
      # ensure that $OBS_SIGND gets restarted if already started
      systemctl is-active $OBS_SIGND 2>&1 > /dev/null
      if [ $? -eq 0 ] ; then
        logline "Restarting $OBS_SIGND"
        systemctl restart $OBS_SIGND
      fi
    fi
    if [ ! -e "$backenddir"/obs-default-gpg.asc ] ; then
        sed -i 's,^\(our $sign =.*\),# \1,' /usr/lib/obs/server/BSConfig.pm
        ENABLE_FORCEPROJECTKEYS=0
    fi
    systemctl is-enabled $OBS_SIGND 2>&1 > /dev/null
    if [ $? == 0 ];then
      systemctl is-failed $OBS_SIGND 2>&1 > /dev/null
      if [ $? == 0 ];then
        logline "obssignd failed to start. Restarting!"
        systemctl status $OBS_SIGND # for debugging output
        systemctl restart $OBS_SIGND
      fi
    fi
  fi

}

###############################################################################

function prepare_os_settings {
  . /etc/os-release
  for d in $ID_LIKE $ID;do
    case $d in
      suse|opensuse)
        MYSQL_SERVICE=mysql
        HTTPD_SERVICE=apache2
        HTTPD_USER=wwwrun
        HTTPD_GROUP=www
        PASSENGER_CONF=/etc/$HTTPD_SERVICE/conf.d/mod_passenger.conf
        TRUST_ANCHORS_DIR=/usr/share/pki/trust/anchors
        UPDATE_SSL_TRUST_BIN=update-ca-certificates
        MOD_PASSENGER_CONF=/etc/$HTTPD_SERVICE/conf.d/mod_passenger.conf
        INST_PACKAGES_CMD="zypper --non-interactive install"
        APACHE_ADDITIONAL_PACKAGES="$HTTPD_SERVICE apache2-mod_xforward rubygem-passenger-apache2 memcached"
        CONFIGURE_APACHE=1
        OBS_SIGND=obssignd
        SIGND_BIN="/usr/sbin/signd"
      ;;
      fedora)
        MYSQL_SERVICE=mariadb
        HTTPD_SERVICE=httpd
        HTTPD_USER=apache
        HTTPD_GROUP=apache
        PASSENGER_CONF=/etc/$HTTPD_SERVICE/conf.d/passenger.conf
        TRUST_ANCHORS_DIR=/etc/pki/ca-trust/source/anchors
        UPDATE_SSL_TRUST_BIN=update-ca-trust
        MOD_PASSENGER_CONF=/etc/$HTTPD_SERVICE/conf.d/passenger.conf
        INST_PACKAGES_CMD="dnf -y install"
        APACHE_ADDITIONAL_PACKAGES="$HTTPD_SERVICE mod_xforward mod_passenger memcached"
        CONFIGURE_APACHE=0
        OBS_SIGND=signd
        SIGND_BIN="/usr/sbin/signd"
      ;;
    esac
  done
}

###############################################################################

function enable_forceprojectkeys {
  # Only run on initial setup
  echo "Starting enable_forceprojectkeys"
  if [ -z "$RUN_INITIAL_SETUP" ];then
    echo "Not running in intial setup mode. Skipping"
    return
  fi

  # This is done manually and not via api to avoid authentication
  # and service dependency (systemd) problems.
  cd $apidir
  echo " - Setting enforce_project_keys in api_production.configurations to '$ENABLE_FORCEPROJECTKEYS'"
  mysql -u $MYSQL_USER -p$MYSQL_PASS -e "update configurations SET enforce_project_keys=$ENABLE_FORCEPROJECTKEYS" api_production || exit 1

  echo " - Starting 'rails writeconfiguration'"
  RAILS_ENV=production bin/rails writeconfiguration || exit 1
}

###############################################################################

function create_sign_cert {
  echo "Starting create_sign_cert"
  if [ -f "$backenddir/obs-default-gpg.asc" -a ! -f "$backenddir/obs-default-gpg.cert" ];then
    echo "Creating new signer cert"
    GNUPGHOME="$backenddir/gnupg" sign --test-sign $SIGND_BIN -C $backenddir/obs-default-gpg.asc > $backenddir/obs-default-gpg.cert 2>&1 || { cat $backenddir/obs-default-gpg.cert ; exit 1; }
  else
    echo "Skipping new signer cert"
  fi
}

###############################################################################
function set_gpg_expiry_date {
  export GNUPGHOME="$backenddir/gnupg"
  KEYID=`gpg -k --with-colons --no-tty --batch| awk -F: '/^pub:/ { print $5 }'`
  EXPIRE=`gpg -k --no-tty $KEYID|grep expires`

  if [ -z "$EXPIRE" ];then
    echo "Set expire date "
    echo -en "expire\n30y\nquit\ny\n" | gpg --no-tty --command-fd 0 --expert --edit-key $KEYID
    gpg --export -a  $KEYID > $backenddir/obs-default-gpg.asc
  fi
  EXPIRE=`gpg -k --no-tty $KEYID|grep expires`
  [ -z "$EXPIRE" ] && exit 1
}
###############################################################################
