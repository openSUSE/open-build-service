#!/bin/bash

echo -e "\ninstalling required software packages...\n"
echo 'solver.allowVendorChange = true' >> /etc/zypp/zypp.conf
zypper -q ar -f http://download.opensuse.org/repositories/OBS:/Server:/Unstable/openSUSE_13.2/OBS:Server:Unstable.repo
zypper -q --gpg-auto-import-keys refresh
zypper -q -n install ruby-devel make gcc patch cyrus-sasl-devel openldap2-devel libmysqld-devel libxml2-devel zlib-devel libxslt-devel nodejs mariadb memcached sphinx screen sphinx obs-server

echo -e "\ndisabling versioned gem binary names...\n"
echo 'install: --no-format-executable' >> /etc/gemrc

echo -e "\ninstalling bundler...\n"
gem install bundler

echo -e "\ninstalling your bundle...\n"
su - vagrant -c "cd /vagrant/src/api/; bundle install --quiet"

echo -e "\nsetting up mariadb...\n"
systemctl start mysql
systemctl enable mysql
mysqladmin -u root password 'opensuse' 

echo -e "\nsetting up memcached...\n"
systemctl start memcached
systemctl enable memcached

# Configure the database if it isn't
if [ ! -f /vagrant/src/api/config/database.yml ] && [ -f /vagrant/src/api/config/database.yml.example ]; then
  echo -e "\nSetting up your database from config/database.yml...\n"
  export DATABASE_URL="mysql2://root:opensuse@localhost/api_development"
  cd /vagrant/src/api
  rake -f /vagrant/src/api/Rakefile db:create
  rake -f /vagrant/src/api/Rakefile db:setup
  rake -f /vagrant/src/api/Rakefile test:unit/watched_project_test
  cd -
else
  echo -e "\nnWARNING: You have already configured your database in config/database.yml." 
  echo -e "WARNING: Please make sure this configuration works in this vagrant box!\n\n" 
fi

# Configure the app if it isn't
if [ ! -f /vagrant/src/api/config/options.yml ] && [ -f /vagrant/src/api/config/options.yml.example ]; then
  echo "Configuring your app in config/options.yml..." 
  sed 's/source_port: 5352/source_port: 3200/' /vagrant/src/api/config/options.yml.example > /vagrant/src/api/config/options.yml
else
  echo -e "\n\nWARNING: You have already configured your app in config/options.yml." 
  echo -e "WARNING: Please make sure this configuration works in this vagrant box!\n\n" 
fi 

echo "Setting up your OBS test backend..."
# Put the backend data dir outside the shared folder so it can use hardlinks
# which isn't possible with VirtualBox shared folders...
mkdir /tmp/vagrant_tmp
chown vagrant:users /tmp/vagrant_tmp
echo -e "/tmp/vagrant_tmp /vagrant/src/api/tmp none bind 0 0" >> /etc/fstab

echo -e "\nProvisioning of your OBS API rails app done!"
echo -e "To start your development OBS backend run: vagrant exec ./script/start_test_backend\n"
echo -e "To start your development OBS frontend run: vagrant exec rails s\n"
