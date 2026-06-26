#!/bin/bash

# make sure that we run as root
if [ $EUID -ne 0 ]
then
  echo "Run as root!"
  exit 1
fi

# make sure that we do not overwrite /root/open-build-service
if [ -e /root/open-build-service ]
then
  echo "/root/open-build-service exists - would be overwritten!"
  exit 1
fi

# FIXME: calculate dist based on current installation
dist="Fedora_31"
repo=OBS:Server:Unstable
repo_path=`echo $repo|sed -e 's,:,:/,g'`
echo "configuring $repo"
curl https://download.opensuse.org/repositories/$repo_path/$dist/$repo.repo > /etc/yum.repos.d/$repo.repo || exit 1

####
# install required packages
####
# install packages needed for a working OBS instance
dnf -y install obs-signd obs-build osc obs-server obs-api obs-worker obs-service-tar_scm obs-service-obs_scm obs-service-set_version obs-service-tar mariadb-server httpd mod_xforward mod_ssl sphinx || exit 1
# install packages needed for test suite
dnf -y install perl-Test-Most perl-Devel-Cover || exit 1

# configure OBS default config
perl -p -i -e 's/^OBS_API_AUTOSETUP=.*/OBS_API_AUTOSETUP="yes"/' /etc/sysconfig/obs-server || exit 1
perl -p -i -e 's/^OBS_STORAGE_AUTOSETUP=.*/OBS_STORAGE_AUTOSETUP="yes"/' /etc/sysconfig/obs-server || exit 1
perl -p -i -e 's/OBS_USE_SLP="yes"/OBS_USE_SLP="no"/' /etc/sysconfig/obs-server || exit 1
perl -p -i -e "s/^\s*OBS_WORKER_INSTANCES=.*/OBS_WORKER_INSTANCES=1/" /etc/sysconfig/obs-server || exit 1

#####
# Configure apache
# Comment out everything in ssl.conf, we use vhost configuration from obs-apache24.conf
perl -p -i -e 's/^/#/' /etc/httpd/conf.d/ssl.conf

# enable port 443 in httpd
perl -p -i -e 's/#Listen 443/Listen 443/' /etc/httpd/conf.d/obs.conf

# Reconfigure passenger.conf
cat <<EOF > /etc/httpd/conf.d/passenger.conf
<IfModule mod_passenger.c>
   PassengerRoot /usr/share/passenger/phusion_passenger/locations.ini
   PassengerRuby /usr/bin/ruby
   PassengerInstanceRegistryDir /var/run/passenger-instreg
   PassengerUser apache
   PassengerGroup apache
</IfModule>
EOF

#####
# setup backend
#####
systemctl start obsstoragesetup || exit 1

#####
# enable and start source server
#####
# if no source server is started, obsapisetup will fail
echo "systemctl enable --now obs$i"
systemctl enable --now obssrcserver || exit 1

#####
# setup all services required/recommended for an appliance
#####
sh -x /usr/lib/obs/server/setup-appliance.sh --non-interactive > /tmp/setup-appliance.log 2>&1 || exit 1

# Reconfigure service file of signd as we use the default
# package from fedora which does not use /srv/obs/gnupg as
# GNUPGHOME to search for secret keys
echo "GNUPGHOME=/srv/obs/gnupg" >> /etc/sysconfig/signd
cat <<EOF > /etc/systemd/system/signd.service
[Unit]
Description=GPG Sign Daemon
After=syslog.target

[Service]
EnvironmentFile=-/etc/sysconfig/signd
Type=forking
PIDFile=/var/run/signd.pid
ExecStart=/usr/sbin/signd -f
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

systemctl restart signd

# required for further test cases
echo -en "[client]\nuser = root\npassword = opensuse\n" > /root/.my.cnf || exit 1
