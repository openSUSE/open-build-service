#!/bin/bash 

function allow_vendor_change() {
  echo 'solver.allowVendorChange = true' >> /etc/zypp/zypp.conf
}

function add_common_repos() {
  zypper -q rr systemsmanagement-chef
  zypper -q rr systemsmanagement-puppet
  zypper -q ar -f http://download.opensuse.org/repositories/OBS:/Server:/Unstable/openSUSE_42.1/OBS:Server:Unstable.repo
  zypper -q ar -f http://download.opensuse.org/repositories/openSUSE:/Tools/openSUSE_42.1/openSUSE:Tools.repo
  zypper -q --gpg-auto-import-keys refresh
  zypper -q -n dup -l --replacefiles
}

function install_common_packages() {
  echo -e "\ninstalling required software packages...\n"
  zypper -q -n install --replacefiles\
    update-alternatives make gcc gcc-c++ patch cyrus-sasl-devel openldap2-devel \
    libmysqld-devel libxml2-devel zlib-devel libxslt-devel nodejs mariadb memcached \
    sphinx phantomjs haveged \
    screen \
    ruby2.4-devel \
    ruby2.4-rubygem-bundler \
    ruby2.4-rubygem-mysql2 \
    ruby2.4-rubygem-nokogiri \
    ruby2.4-rubygem-multi_json \
    ruby2.4-rubygem-ruby-ldap \
    ruby2.4-rubygem-xmlhash \
    ruby2.4-rubygem-thinking-sphinx\
    ruby2.4-rubygem-foreman\
    perl-GD \
    perl-XML-Parser \
    perl-Devel-Cover \
    obs-server \
    perl-BSSolv \
    perl-Socket-MsgHdr \
    perl-JSON-XS \
    curl \
    vim-data \
    psmisc \
    obs-service-download_src_package obs-service-download_files obs-service-download_url \
    obs-service-format_spec_file obs-service-kiwi_import \
    osc

  # This is a workaround for a very strange behavior
  # After installing one of the follwing packages - obs-server, curl or vim-data
  # grub installation is broken, if we don`t re-install grub, the VM will hang
  # on reboot
  grub2-install /dev/sda
}

# Needed for single_test and other things that just call ruby in the env
function setup_ruby() {
  echo -e "\nsetting up ruby...\n"
  su - vagrant -c "ln -sf /usr/bin/ruby.ruby2.4 /home/vagrant/bin/ruby"
}

function setup_ruby_gem() {
  echo -e "\ndisabling versioned gem binary names...\n"
  echo 'install: --no-format-executable' >> /etc/gemrc
}

function install_bundle() {
  echo -e "\ninstalling your bundle...\n"
  su - vagrant -c "cd /vagrant/src/api/; bundle install --quiet"
}

function setup_mariadb() {
  echo -e "\nsetting up mariadb...\n"
  systemctl restart mysql
  systemctl enable mysql
  check_for_databases || mysqladmin -u root password 'opensuse'
}

function setup_memcached() {
  echo -e "\nsetting up memcached...\n"
  systemctl restart memcached
  systemctl enable memcached
}

function configure_app() {
  copy_example_file options.yml || return 1
}

function configure_database() {
  copy_example_file database.yml || return 1
  check_for_databases && return 1
  rake -f /vagrant/src/api/Rakefile db:create
  rake -f /vagrant/src/api/Rakefile db:setup
}

function configure_search() {
  rake -f /vagrant/src/api/Rakefile ts:rebuild
}

function setup_signd() {
  echo "Setting up signd so bs_signer can be used..."
  cd / && tar xf /vagrant/dist/obs-signd-conf.tar.bz2
  systemctl enable haveged
  systemctl start haveged
  systemctl enable obssignd
  systemctl start obssignd
}

function setup_data_dir() {
  echo "Generating data dir and mounting them So hard links can be used..."
  # Put the backend data dir outside the shared folder so it can use hardlinks
  # which isn't possible with VirtualBox shared folders...
  _prepare_bound_directory tmp
  _prepare_bound_directory log
  mount -a

}

function print_final_information() {
  echo -e "\nProvisioning of your OBS API rails app done!"
  echo -e "To start your development OBS backend run: vagrant exec contrib/start_development_backend\n"
  echo -e "To start your development OBS frontend run: vagrant exec rails server\n"
  echo -e "\nHappy hacking!\n"
}

function chown_vagrant_owned_dirs() {

  BASE_DIR=/vagrant/src/api/
  # create log files to ensure they are owned by vagrant
    for dir in log tmp
    do
      chown -R vagrant:users $BASE_DIR/$dir
    done

}

function prepare_apache2 {

  echo -e "\nPreparing apache setup\n"

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

  systemctl enable apache2.service
}

##### INTERNAL FUNCTIONS #####

function copy_example_file {
  if [ -z $1 ]; then
    return 1
  fi

  if [ ! -f /vagrant/src/api/config/$1 ] && [ -f /vagrant/src/api/config/$1.example ]; then
    echo "Setting up config/$1 from config/$1.exmaple"
    cp /vagrant/src/api/config/$1.example /vagrant/src/api/config/$1
  else
    echo "WARNING: You already have the config file $1, make sure it works with vagrant"
    return 1
  fi
}

function check_for_databases {
  echo "show databases" | mysql -u root --password=opensuse|grep -q api_ && return 0 || return 1
}

function _prepare_bound_directory() {

  DIRNAMEEXT=$1
  TMP_DIR=/tmp/vagrant_$1
  MOUNT_DIR=/vagrant/src/api/$1
  for dir in $MOUNT_DIR $TMP_DIR
  do
    if [ ! -d $dir ];then
      echo " - Creating directory $dir"
      mkdir -p $dir
    fi
    chown vagrant:users $dir
  done

  # create log files to ensure they are owned by vagrant
  if [ "$1" == "log" ];then
    for log in backend_access.log  development.log  test.log
    do
      touch $TMP_DIR/$log
    done
  fi

  chown vagrant:users -R $TMP_DIR

  TMP_IN_FSTAB=$(grep "$MOUNT_DIR" /etc/fstab)
  if [ -z "$TMP_IN_FSTAB" ];then
    echo " - Adding $TMP_DIR to fstab"
    echo -e "$TMP_DIR $MOUNT_DIR none bind 0 0" >> /etc/fstab
  fi

}
