#!/bin/bash 

MYSQL_USER=root
MYSQL_PASSWD=opensuse

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
 
}

echo -e "\nPreparing additional services"
echo 'solver.allowVendorChange = true' >> /etc/zypp/zypp.conf

for repo in \
http://download.opensuse.org/repositories/devel:/languages:/perl/openSUSE_13.2/devel:languages:perl.repo \
http://download.opensuse.org/repositories/OBS:/Server:/Unstable/openSUSE_13.2/OBS:Server:Unstable.repo
do
  zypper -q ar -f $repo
done


echo -e "\ninstalling required software packages...\n"
zypper -q --gpg-auto-import-keys refresh
zypper -q -n install update-alternatives ruby-devel make gcc gcc-c++ patch cyrus-sasl-devel openldap2-devel libmysqld-devel libxml2-devel zlib-devel libxslt-devel nodejs mariadb memcached sphinx screen sphinx obs-server phantomjs mysql apache2 

echo -e "\nsetup ruby binaries...\n"
for bin in rake rdoc ri; do
   /usr/sbin/update-alternatives --set $bin /usr/bin/$bin.ruby.ruby2.2
done

echo -e "\ndisabling versioned gem binary names...\n"
echo 'install: --no-format-executable' >> /etc/gemrc

echo -e "\ninstalling bundler...\n"
gem install bundler

echo -e "\ninstalling your bundle...\n"
su - vagrant -c "cd /vagrant/src/api/; bundle install --quiet"

    [ -d /srv/www/obs/api/config/ ] || mkdir -p /srv/www/obs/api/config/
    cp /vagrant/src/api/config/database.yml.example /srv/www/obs/api/config/database.yml
    cp /vagrant/src/api/config/options.yml.example /srv/www/obs/api/config/options.yml

    echo -e "\nChanging mysql password and settings\n"

    systemctl start mysql.service
    mysqladmin -u $MYSQL_USER password "$MYSQL_PASSWD" 
    cat <<EOF >/root/.my.cnf

[client]
password=$MYSQL_PASSWD
user=$MYSQL_USER

[mysqladmin]
password=$MYSQL_PASSWD
user=$MYSQL_USER

EOF
  
    
echo -e "\nInstalling backend components\n"
cp -a /vagrant/src/backend  /usr/lib/obs/server

echo -e "\nEnabling backend services\n"
for srv in obsapidelayed obsapisetup obsdispatcher obspublisher obsrepserver obsscheduler obssrcserver;do
  cp /vagrant/dist/$srv /etc/init.d
  systemctl enable $srv.service
done

for dir in /srv/obs /srv/www/obs /srv/www/obs/overview/ /usr/lib/obs /srv/www/obs/api/log/ /srv/www/obs/api/tmp;do
  [ -d $dir ] || mkdir -p $dir
done 

for srv in apache2 mysql memcached;do
  systemctl enable $srv.service
done

echo -e "\nInstalling api components\n"
cp -a /vagrant/src/api /srv/www/obs
cp -a /vagrant/dist/obs-apache24.conf /etc/apache2/vhosts.d/obs.conf
cp /vagrant/dist/overview.html.TEMPLATE /srv/www/obs/overview/
cd /srv/www/obs/api/ 
echo "" | sha256sum|awk '{print $1}' > config/secret.key  
chown wwwrun:www -R /srv/www/obs/api/log/
chown wwwrun:www -R /srv/www/obs/api/tmp

echo -e "\nInstalling obsapisetup components\n"
[ -d /usr/share/doc/packages/obs-server/contrib ] || mkdir -p /usr/share/doc/packages/obs-server/contrib
cp /vagrant/dist/setup-appliance.sh /usr/share/doc/packages/obs-server/contrib
perl -p -i -e 's#BS_API_AUTOSETUP=.*#BS_API_AUTOSETUP="yes"#' /etc/sysconfig/obs-server 

prepare_apache2 

cd /srv/www/obs/api

bundle exec rake assets:precompile RAILS_ENV=production RAILS_GROUPS=assets 2>/dev/null

touch /srv/www/obs/api/config/production.sphinx.conf 
chown wwwrun:www /srv/www/obs/api/config/production.sphinx.conf


exit 0

