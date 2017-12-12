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
function check_service {
  srv=$1
  service_critical=$2

  [[ $SETUP_ONLY == 1 ]] && return

  echo "Checking service $srv ..."

  logline "Enabling $srv"
  execute_silently systemctl enable $srv\.service
  if [[ $? -gt 0 ]];then
    logline "WARNING: Enabling $srv daemon failed."
  fi

  STATUS=`systemctl is-active $srv\.service 2>/dev/null`
  if [[ "$STATUS" == "inactive" ]];then
    echo "$srv daemon not started. Trying to start"
    execute_silently systemctl start $srv\.service
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
     FQHOSTNAME=`hostname -f 2>/dev/null`
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
      sed -i 's,^external_frontend_host: .*,frontend_host: "'"$FQHOSTNAME"'",' $api_options_yml
      sed -i 's,^external_frontend_port: .*,frontend_port: 443,' $api_options_yml
      sed -i 's,^external_frontend_protocol: .*,frontend_protocol: "'"https"'",' $api_options_yml

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
  chown obsrun.obsrun $backenddir/repos
}
###############################################################################
function prepare_database_setup {
 
  cd /srv/www/obs/api 
  RAILS_ENV=production rails.ruby2.4 db:migrate:status > /dev/null

  if [[ $? > 0 ]];then
    echo "Initialize MySQL databases (first time only)"
    echo " - reconfiguring /etc/my.cnf"
    perl -p -i -e 's#.*datadir\s*=\s*/var/lib/mysql$#datadir= /srv/obs/MySQL#' /etc/my.cnf
    echo " - installing to new datadir"
    mysql_install_db
    echo " - changing ownership for new datadir"
    chown mysql:mysql -R /srv/obs/MySQL
    echo " - restarting mysql"
    systemctl restart mysql
    echo " - setting new password for user root in mysql"
    mysqladmin -u root password "opensuse"
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
    RAKE_COMMANDS="db:create db:setup writeconfiguration"
  else
    logline "Migrate OBS api database"
    cd $apidir
    RAKE_COMMANDS="db:migrate"
    echo
  fi

  logline "Setting ownership of '$backenddir' obsrun"
  chown obsrun.obsrun $backenddir

  logline "Setting up rails environment"
  for cmd in $RAKE_COMMANDS
  do
    logline " - Doing 'rails.ruby2.4 $cmd'"
    RAILS_ENV=production bundle exec rails.ruby2.4 $cmd >> $apidir/log/db_migrate.log
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
      install -d -m 0700 $backenddir/certs
      openssl genrsa -out $backenddir/certs/server.key 1024 2>/dev/null
  fi
}
###############################################################################
function import_ca_cert {
  # apache has to trust the api ssl certificate
  if [ ! -e /etc/ssl/certs/server.${FQHOSTNAME}.crt ]; then
    cp $backenddir/certs/server.${FQHOSTNAME}.crt \
      /usr/share/pki/trust/anchors/server.${FQHOSTNAME}.pem
    update-ca-certificates
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
  chown -R wwwrun.www $apidir/log
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
    ACTIVE=`systemctl is-active $srv`
    [[ "$ENABLED" == "enabled" ]] || systemctl enable $srv
    [[ "$ACTIVE" == "active" ]] || systemctl start $srv
  done

}
###############################################################################
function check_recommended_backend_services {

  [[ $SETUP_ONLY == 1 ]] && return 
  RECOMMENDED_SERVICES="obsdodup obsdeltastore obssigner obssignd obsservicedispatch"

  for srv in $RECOMMENDED_SERVICES;do
    STATE=$(chkconfig $srv|awk '{print $2}')
    if [[ $STATE != on ]];then
      ask "Service $srv is not enabled. Would you like to enable it? [Yn]" "y"
      case $rv in
        y|yes|Y|YES)
          systemctl enable $srv
          systemctl start $srv
        ;;
      esac
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
  OPTIONAL_SERVICES="obswarden obsapisetup obsstoragesetup obsworker obsservice"

  for srv in $OPTIONAL_SERVICES;do
    STATE=$(chkconfig $srv|awk '{print $2}')
    if [[ $STATE != on ]];then
      ask "Service $srv is not enabled. Would you like to enable it? [yN]" $DEFAULT_ANSWER
      case $rv in
        y|yes|Y|YES)
          systemctl enable $srv
          systemctl start $srv
        ;;
      esac
    fi
  done
}
###############################################################################
function prepare_apache2 {

  [[ $SETUP_ONLY == 1 ]] && return 

  PACKAGES="apache2 apache2-mod_xforward rubygem-passenger-apache2 memcached"
  PKG2INST=""
  for pkg in $PACKAGES;do
    rpm -q $pkg >/dev/null || PKG2INST="$PKG2INST $pkg"
  done

  if [[ -n $PKG2INST ]];then
    zypper --non-interactive install $PKG2INST >/dev/null
  fi

  MODULES="passenger rewrite proxy proxy_http xforward headers socache_shmcb"

  for mod in $MODULES;do
    a2enmod -q $mod || a2enmod $mod
  done

  FLAGS=SSL

  for flag in $FLAGS;do
    a2enflag $flag >/dev/null
  done

}
###############################################################################
function prepare_passenger {

  perl -p -i -e \
    's#^(\s*)PassengerRuby "/usr/bin/ruby"#$1\PassengerRuby "/usr/bin/ruby.ruby2.4"#' \
      /etc/apache2/conf.d/mod_passenger.conf
 

}
###############################################################################
function prepare_obssigner {

  # Only used if there is a local BSConfig
  if [ -e /usr/lib/obs/server/BSConfig.pm ]; then
    # signing setup
    perl -p -i -e 's,^\s*#\s*our \$gpg_standard_key.*,our \$gpg_standard_key = "/srv/obs/obs-default-gpg.asc";,' /usr/lib/obs/server/BSConfig.pm
    perl -p -i -e 's,^\s*#\s*our \$keyfile.*,our \$keyfile = "/srv/obs/obs-default-gpg.asc";,' /usr/lib/obs/server/BSConfig.pm
    perl -p -i -e 's,^\s*#\s*our \$sign = .*,our \$sign = "/usr/bin/sign";,' /usr/lib/obs/server/BSConfig.pm
    perl -p -i -e 's,^\s*#\s*our \$forceprojectkeys.*,our \$forceprojectkeys = 1;,' /usr/lib/obs/server/BSConfig.pm
    chmod 4755 /usr/bin/sign

    # create default gpg key if not existing
    if [ ! -e "$backenddir"/obs-default-gpg.asc ] && grep -q "^our \$keyfile.*/obs-default-gpg.asc.;$" /usr/lib/obs/server/BSConfig.pm; then
      GPG_KEY_CREATED=1
      echo -n Generating OBS default GPG key ....
      mkdir -p "$backenddir"/gnupg/phrases
      chmod -R 0700 "$backenddir"/gnupg
      cat >/tmp/obs-gpg.$$ <<EOF
           %echo Generating a default OBS instance key
           Key-Type: DSA
           Key-Length: 1024
           Subkey-Type: ELG-E
           Subkey-Length: 1024
           Name-Real: private OBS
           Name-Comment: key without passphrase
           Name-Email: defaultkey@localobs
           Expire-Date: 0
           %pubring $backenddir/gnupg/pubring.gpg
           %secring $backenddir/gnupg/secring.gpg
           %commit
           %echo done
EOF
      gpg2 --homedir $backenddir/gnupg --batch --gen-key /tmp/obs-gpg.$$
      gpg2 --homedir $backenddir/gnupg --export -a > "$backenddir"/obs-default-gpg.asc
      # empty file just for accepting the key
      touch "$backenddir/gnupg/phrases/defaultkey@localobs"
    fi
    # to update sign.conf also after an appliance update
    if [ -e "$backenddir"/obs-default-gpg.asc ] && ! grep -q "^user" /etc/sign.conf; then
      # extend signd config
      echo "user: defaultkey@localobs"   >> /etc/sign.conf
      echo "server: 127.0.0.1"           >> /etc/sign.conf
      echo "allowuser: obsrun"           >> /etc/sign.conf
      echo "allow: 127.0.0.1"            >> /etc/sign.conf
      echo "phrases: $backenddir/gnupg/phrases" >> /etc/sign.conf
      echo done
      rm /tmp/obs-gpg.$$
      sed -i 's,^# \(our $sign =.*\),\1,' /usr/lib/obs/server/BSConfig.pm
      sed -i 's,^# \(our $forceprojectkeys =.*\),\1,' /usr/lib/obs/server/BSConfig.pm
    fi
    if [ ! -e "$backenddir"/obs-default-gpg.asc ] ; then
        sed -i 's,^\(our $sign =.*\),# \1,' /usr/lib/obs/server/BSConfig.pm
        sed -i 's,^\(our $forceprojectkeys =.*\),# \1,' /usr/lib/obs/server/BSConfig.pm
    fi

  fi

}

function setup_registry {
  # check if docker registry is installed or return
  logline "Starting container registry setup!"
  rpm -q --quiet obs-container-registry
  if [ $? -gt 0 ];then
    logline "Package 'obs-container-registry' not found. Skipping registry setup!"
    return
  fi

  # check if $container_registries already configured in BSConfig and return
  grep -q -P '^\s*our\s+\$container_registries\s*=' /usr/lib/obs/server/BSConfig.pm
  if [ $? -lt 1 ];then
    logline "Configuration for container_registries already active in BSConfig. Skipping registry setup!"
    return
  fi

  # check if $publish_containers already configured in BSConfig and return
  grep -q -P '^\s*our\s+\$publish_containers\s*=' /usr/lib/obs/server/BSConfig.pm
  if [ $? -lt 1 ];then
    logline "Configuration for publish_containers already active in BSConfig. Skipping registry setup!"
    return
  fi

  # reconfigure docker registry only to be accessible via apache proxy
  logline "Bind registry to loopback interface only"
  perl -p -i -e  "s/0.0.0.0:5000/127.0.0.1:5000 # config changed by $0/" /etc/registry/config.yml

  # restart registry to reread confi if already started
  logline "Activating registry startup"
  systemctl status registry && systemctl restart registry

  systemctl enable registry
  systemctl start registry

  # configure $container_registries and $publish_containers
  # in BSConfig
  logline "Configuring local container registry in BSConfig"
  cat <<EOF >> /usr/lib/obs/server/BSConfig.pm
### Configuration added by $0
our \$container_registries = {
   'localhost' => {
     server => 'https://localhost:444',
     user => 'ignored',
     password => 'ignored',
     # Please be aware of the trailing slash
     repository_base => '/',
   }
};

our \$publish_containers = [
   '.*' => ['localhost'],
];
###
1;
EOF

  # check obspublisher and restart if needed
  logline "Checking obspublisher and restart if required."
  systemctl status obspublisher && systemctl restart obspublisher

  logline "Finished container registry setup!"
}

###############################################################################
#
# MAIN
#
###############################################################################

export LC_ALL=C

ENABLE_OPTIONAL_SERVICES=0

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


if [[ ! $BOOTSTRAP_TEST_MODE == 1 && $0 != "-bash" ]];then

  NON_INTERACTIVE=0

  while [[ $1 ]];do
    case $1 in
      --non-interactive) NON_INTERACTIVE=1;;
      --setup-only) SETUP_ONLY=1;;
      --enable-optional-services) ENABLE_OPTIONAL_SERVICES=1;;
    esac
    shift
  done

  # prepare configuration for obssigner before any other backend service
  # is started, because obssigner configuration might affect other services
  # too
  GPG_KEY_CREATED=0

  prepare_obssigner

  if [[ $GPG_KEY_CREATED == 1 ]];then
    pushd .
    # avoid systemctl
    cd /etc/init.d
    ./obssrcserver reload
    ./obsrepserver reload
    popd
  fi

  check_required_backend_services

  check_recommended_backend_services

  check_optional_backend_services

  check_service mysql 1

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
  OS=`head -n 1 /etc/SuSE-release`
  RUN_INITIAL_SETUP=""

  prepare_database_setup

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

  check_service apache2

  check_service memcached

  # make sure that apache gets restarted after cert change
  if [[ $DETECTED_CERT_CHANGE && ! $SETUP_ONLY ]];then
      systemctl reload apache2
  fi

  check_service obsapidelayed

  create_issue_file

  setup_registry

  if [ -n "$FQHOSTNAME" ]; then
    create_overview_html
    add_login_info_to_issue
  else
    network_failure_warning
  fi

  exit 0

fi
