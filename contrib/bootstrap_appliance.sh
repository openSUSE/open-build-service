#!/bin/bash 

MYSQL_USER=root
MYSQL_PASSWD=opensuse
OBS_DIST_ID="openSUSE_Leap_42.1"

BASEDIR=`dirname $0`
. $BASEDIR/common.sh


allow_vendor_change

for repo in \
  http://download.opensuse.org/repositories/devel:/languages:/perl/$OBS_DIST_ID/devel:languages:perl.repo
do
  zypper -q ar -f $repo
done

add_common_repos

install_common_packages


setup_ruby

install_bundle

[ -d /srv/www/obs/api/config/ ] || mkdir -p /srv/www/obs/api/config/
cp /vagrant/src/api/config/database.yml.example /srv/www/obs/api/config/database.yml
cp /vagrant/src/api/config/options.yml.example /srv/www/obs/api/config/options.yml

echo -e "\nChanging mysql password and settings\n"

systemctl start mysql.service
systemctl enable mysql.service

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
  echo " - Working on $srv"
  cp /vagrant/dist/$srv /etc/init.d
  systemctl enable $srv\.service
done

echo -e "\nChecking required directories\n"
for dir in /srv/obs /srv/www/obs /srv/www/obs/overview/ /usr/lib/obs /srv/www/obs/api/log/ /srv/www/obs/api/tmp;do
  echo " - Checking $dir"
  [ -d $dir ] || mkdir -p $dir
done 

setup_memcached

prepare_apache2

echo -e "\nInstalling api components\n"
cp -a /vagrant/src/api /srv/www/obs
cp -a /vagrant/dist/obs-apache24.conf /etc/apache2/vhosts.d/obs.conf
cp /vagrant/dist/overview.html.TEMPLATE /srv/www/obs/overview/
cd /srv/www/obs/api/ 
echo "" | sha256sum|awk '{print $1}' > config/secret.key  
chown wwwrun:www -R /srv/www/obs/api/log/
chown wwwrun:www -R /srv/www/obs/api/tmp

echo -e "\nInstalling obsapisetup components\n"
make -C /vagrant/dist install

echo -e "\nConfiguring BS_API_AUTOSETUP\n"
perl -p -i -e 's#BS_API_AUTOSETUP=.*#BS_API_AUTOSETUP="yes"#' /etc/sysconfig/obs-server 


cd /srv/www/obs/api

bundle exec rake assets:precompile RAILS_ENV=production RAILS_GROUPS=assets 2>/dev/null

touch /srv/www/obs/api/config/production.sphinx.conf 
chown wwwrun:www /srv/www/obs/api/config/production.sphinx.conf

echo "fstab content"
cat /etc/fstab

exit 0
