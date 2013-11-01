#
# spec file for package obs-server
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


%if 0%{?fedora}
%global sbin /usr/sbin
%else
%global sbin /sbin
%endif

%if 0%{?fedora} || 0%{?rhel}
%global apache_user apache
%global apache_group apache
%else
%global apache_user wwwrun
%global apache_group www
%endif

Name:           obs-server
Summary:        The Open Build Service -- Server Component
License:        GPL-2.0 and GPL-3.0
%if 0%{?suse_version} < 1210 && 0%{?suse_version:1}
Group:          Productivity/Networking/Web/Utilities
%endif
Version:        2.4.50_382_g5ef3c6a
Release:        0
Url:            http://en.opensuse.org/Build_Service
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
# Sources are retrieved using script which is attached as Source2
Source:         obs-server-%version.tar.bz2
Source2:        update-sources.sh
BuildRequires:  python-devel
# make sure this is in sync with the RAILS_GEM_VERSION specified in the
# config/environment.rb of the various applications.
# atm the obs rails version patch above unifies that setting among the applications
# also see requires in the obs-server-api sub package
BuildRequires:  build >= 20130109
BuildRequires:  inst-source-utils
BuildRequires:  perl-BSSolv
BuildRequires:  perl-Compress-Zlib
BuildRequires:  perl-File-Sync >= 0.10
BuildRequires:  perl-JSON-XS
BuildRequires:  perl-Net-SSLeay
BuildRequires:  perl-Socket-MsgHdr
BuildRequires:  perl-TimeDate
BuildRequires:  perl-XML-Parser
BuildRequires:  xorg-x11-server
PreReq:         /usr/sbin/useradd /usr/sbin/groupadd
Requires:       build >= 20130114
Requires:       obs-productconverter >= %version
Requires:       obs-worker
Requires:       perl-BSSolv >= 0.18.0
# Required by source server
Requires:       diffutils
PreReq:         git-core
Requires:       patch
# require the createrepo version which got used in the testsuite
Requires:       %(/bin/bash -c 'rpm -q --qf "%%{name} = %%{version}" createrepo')
# depend hard to new python-yum. There are too many broken versions of yum-common around.
Requires:       python-yum

%if 0%{?suse_version:1}
BuildRequires:  fdupes
PreReq:         %fillup_prereq %insserv_prereq permissions pwdutils
%endif

%if 0%{?suse_version:1}
Recommends:     yum yum-metadata-parser repoview dpkg
Recommends:     deb >= 1.5
Recommends:     lvm2
Recommends:     openslp-server
Recommends:     obs-signd
Recommends:     inst-source-utils
%else
Requires:       dpkg
Requires:       yum
Requires:       yum-metadata-parser
%endif
Requires:       perl-Compress-Zlib
Requires:       perl-File-Sync >= 0.10
Requires:       perl-JSON-XS
Requires:       perl-Net-SSLeay
Requires:       perl-Socket-MsgHdr
Requires:       perl-XML-Parser

%description
The Open Build Service (OBS) backend is used to store all sources and binaries. It also
calculates the need for new build jobs and distributes it.

%package -n obs-worker
Requires:       cpio
Requires:       curl
Requires:       perl-Compress-Zlib
Requires:       perl-TimeDate
Requires:       perl-XML-Parser
Requires:       screen
# For runlevel script:
Requires:       curl
Recommends:     openslp lvm2
Requires:       bash
Requires:       binutils
Requires:       bsdtar
Summary:        The Open Build Service -- Build Host Component
%if 0%{?suse_version}
%if 0%{?suse_version} < 1210
Group:          Productivity/Networking/Web/Utilities
%endif
PreReq:         %fillup_prereq %insserv_prereq
%endif
%if 0%{?suse_version} <= 1030
Requires:       lzma
%endif
%if 0%{?suse_version} >= 1120
BuildArch:      noarch
Requires:       util-linux >= 2.16
%else
%ifarch x86_64
Requires:       linux32
%endif
%ifarch ppc64
Requires:       powerpc32
%endif
%endif

%description -n obs-worker
This is the obs build host, to be installed on each machine building
packages in this obs installation.  Install it alongside obs-server to
run a local playground test installation.

%package -n obs-api
Summary:        The Open Build Service -- The API and WEBUI
%if 0%{?suse_version}
%if 0%{?suse_version} < 1210
Group:          Productivity/Networking/Web/Utilities
%endif
Obsoletes:      obs-common <= 2.2.90
PreReq:         %fillup_prereq %insserv_prereq
%endif

#For apache
Recommends:     apache2 apache2-mod_xforward rubygem-passenger-apache2

# memcache is required for session data
Requires:       memcached
Conflicts:      memcached < 1.4

# For local runs
BuildRequires:  rubygem-sqlite3

Requires:       mysql

Requires:       ruby >= 2.0
# needed for fulltext searching
Requires:       sphinx >= 2.0.8
Supplements:    rubygem-ruby-ldap
BuildRequires:  obs-api-testsuite-deps
BuildRequires:  rubygem-ruby-ldap
# for test suite:
BuildRequires:  createrepo
BuildRequires:  curl
BuildRequires:  memcached >= 1.4
BuildRequires:  mysql
BuildRequires:  netcfg
BuildRequires:  rubygem-ci_reporter
BuildRequires:  xorg-x11-Xvnc
BuildRequires:  xorg-x11-server
BuildRequires:  xorg-x11-server-extra
# OBS_SERVER_BEGIN
Requires:       rubygem(2.0.0:actionmailer) = 4.0.0
Requires:       rubygem(2.0.0:actionpack) = 4.0.0
Requires:       rubygem(2.0.0:activemodel) = 4.0.0
Requires:       rubygem(2.0.0:activerecord) = 4.0.0
Requires:       rubygem(2.0.0:activerecord-deprecated_finders) = 1.0.3
Requires:       rubygem(2.0.0:activesupport) = 4.0.0
Requires:       rubygem(2.0.0:arel) = 4.0.0
Requires:       rubygem(2.0.0:atomic) = 1.1.14
Requires:       rubygem(2.0.0:builder) = 3.1.4
Requires:       rubygem(2.0.0:bundler) = 1.3.4
Requires:       rubygem(2.0.0:clockwork) = 0.6.1
Requires:       rubygem(2.0.0:daemons) = 1.1.9
Requires:       rubygem(2.0.0:dalli) = 2.6.4
Requires:       rubygem(2.0.0:delayed_job) = 4.0.0
Requires:       rubygem(2.0.0:delayed_job_active_record) = 4.0.0
Requires:       rubygem(2.0.0:erubis) = 2.7.0
Requires:       rubygem(2.0.0:hike) = 1.2.3
Requires:       rubygem(2.0.0:hoptoad_notifier) = 2.4.11
Requires:       rubygem(2.0.0:i18n) = 0.6.5
Requires:       rubygem(2.0.0:innertube) = 1.1.0
Requires:       rubygem(2.0.0:json) = 1.8.0
Requires:       rubygem(2.0.0:kaminari) = 0.14.1
Requires:       rubygem(2.0.0:mail) = 2.5.4
Requires:       rubygem(2.0.0:middleware) = 0.1.0
Requires:       rubygem(2.0.0:mime-types) = 1.25
Requires:       rubygem(2.0.0:mini_portile) = 0.5.1
Requires:       rubygem(2.0.0:minitest) = 4.7.4
Requires:       rubygem(2.0.0:mobileesp_converted) = 0.2.2
Requires:       rubygem(2.0.0:multi_json) = 1.7.9
Requires:       rubygem(2.0.0:mysql2) = 0.3.13
Requires:       rubygem(2.0.0:newrelic_rpm) = 3.6.8.164
Requires:       rubygem(2.0.0:nokogiri) = 1.6.0
Requires:       rubygem(2.0.0:pkg-config) = 1.1.4
Requires:       rubygem(2.0.0:polyglot) = 0.3.3
Requires:       rubygem(2.0.0:rack) = 1.5.2
Requires:       rubygem(2.0.0:rack-test) = 0.6.2
Requires:       rubygem(2.0.0:rails) = 4.0.0
Requires:       rubygem(2.0.0:railties) = 4.0.0
Requires:       rubygem(2.0.0:rake) = 10.1.0
Requires:       rubygem(2.0.0:rdoc) = 4.0.1
Requires:       rubygem(2.0.0:riddle) = 1.5.8
Requires:       rubygem(2.0.0:ruby-ldap) = 0.9.16
Requires:       rubygem(2.0.0:sprockets) = 2.10.0
Requires:       rubygem(2.0.0:sprockets-rails) = 2.0.0
Requires:       rubygem(2.0.0:thinking-sphinx) = 3.0.4
Requires:       rubygem(2.0.0:thor) = 0.18.1
Requires:       rubygem(2.0.0:thread_safe) = 0.1.3
Requires:       rubygem(2.0.0:tilt) = 1.4.1
Requires:       rubygem(2.0.0:treetop) = 1.4.15
Requires:       rubygem(2.0.0:tzinfo) = 0.3.37
Requires:       rubygem(2.0.0:xmlhash) = 1.3.6
Requires:       rubygem(2.0.0:yajl-ruby) = 1.1.0
# OBS_SERVER_END
# requires for webui:

Requires:       ghostscript-fonts-std
Summary:        The Open Build Service -- The API and WEBUI
%if 0%{?suse_version} < 1210 && 0%{?suse_version:1}
Group:          Productivity/Networking/Web/Utilities
%endif

%description -n obs-api
This is the API server instance, and the web client for the 
OBS.

%package -n obs-devel
Summary:        The Open Build Service -- The API and WEBUI Testsuite
%if 0%{?suse_version} < 1210 && 0%{?suse_version:1}
Group:          Productivity/Networking/Web/Utilities
%endif
Obsoletes:      obs-webui-testsuite
Requires:       obs-api = %{version}-%{release}
%requires_eq obs-api-testsuite-deps

%description -n obs-devel
Install to track dependencies for git

%package -n obs-source_service
Summary:        The Open Build Service -- source service daemon
%if 0%{?suse_version} < 1210 && 0%{?suse_version:1}
Group:          Productivity/Networking/Web/Utilities
%endif
# Our default services, used in osc and webui
Recommends:     obs-service-download_url
Recommends:     obs-service-verify_file

%description -n obs-source_service
The OBS source service is a component to modify submitted sources
on the server side. This may include source checkout, spec file
generation, gpg validation, quality checks and other stuff.

This component is optional and not required to run the service.


%package -n obs-productconverter
Summary:        The Open Build Service -- product definition utility
%if 0%{?suse_version} < 1210 && 0%{?suse_version:1}
Group:          Productivity/Networking/Web/Utilities
%endif
# For perl library files, TODO: split out obs-lib subpackage?
Requires:       obs-server

%description -n obs-productconverter
bs_productconvert is a utility to create Kiwi- and Spec- files from a
product definition.

%package -n obs-utils
Summary:        The Open Build Service -- utilities
%if 0%{?suse_version} < 1210 && 0%{?suse_version:1}
Group:          Productivity/Networking/Web/Utilities
%endif
Requires:       build
Requires:       osc
Requires:       ruby

%description -n obs-utils
obs_mirror_project is a tool to copy the binary data of a project from one obs to another
obs_project_update is a tool to copy a packages of a project from one obs to another

#--------------------------------------------------------------------------------
%prep
%setup -q
# drop build script, we require the installed one from own package
rm -rf src/build
find . -name .git\* -o -name Capfile -o -name deploy.rb | xargs rm -rf

%build
# we need it for the test suite or it may silently succeed 
test -x /usr/bin/Xvfb 
#
# generate apidocs
#
pushd docs/api/api
make apidocs
popd

%install
#
# First install all dist files
#
cd dist
%if 0%{?fedora} || 0%{?rhel}
  # Fedora use different user:group for apache
  find -type f | xargs sed -i '1,$s/wwwrun\(.*\)www/apache\1apache/g'
  find -type f | xargs sed -i '1,$s/user wwwrun/user apache/g'
  find -type f | xargs sed -i '1,$s/group www/group apache/g'
%endif
# configure apache web service
mkdir -p $RPM_BUILD_ROOT/etc/apache2/vhosts.d/
install -m 0644 obs-apache2.conf $RPM_BUILD_ROOT/etc/apache2/vhosts.d/obs.conf
# install overview page template
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/overview
install -m 0644 overview.html.TEMPLATE $RPM_BUILD_ROOT/srv/www/obs/overview/
# install obs mirror script and obs copy script
install -d -m 755 $RPM_BUILD_ROOT/usr/sbin/
install -m 0755 obs_mirror_project obs_project_update $RPM_BUILD_ROOT/usr/sbin/
# install  runlevel scripts
install -d -m 755 $RPM_BUILD_ROOT/etc/init.d/
for i in obssrcserver obsrepserver obsscheduler obsworker obspublisher obsdispatcher \
         obssigner obswarden obsapidelayed obsapisetup obsstoragesetup \
         obsservice; do
  install -m 0755 $i \
           $RPM_BUILD_ROOT/etc/init.d/
  ln -sf /etc/init.d/$i $RPM_BUILD_ROOT/usr/sbin/rc$i
done
# install logrotate
install -d -m 755 $RPM_BUILD_ROOT/etc/logrotate.d/
for i in obs-api obs-build obs-server ; do
  install -m 0644 ${i}.logrotate \
           $RPM_BUILD_ROOT/etc/logrotate.d/$i
done
# install fillups
FILLUP_DIR=$RPM_BUILD_ROOT/var/adm/fillup-templates
install -d -m 755 $FILLUP_DIR
install -m 0644 sysconfig.obs-server $FILLUP_DIR/
# install SLP registration files
SLP_DIR=$RPM_BUILD_ROOT/etc/slp.reg.d/
install -d -m 755  $SLP_DIR
install -m 644 obs.source_server.reg $SLP_DIR/
install -m 644 obs.repo_server.reg $SLP_DIR/
# create symlink for product converter
mkdir -p $RPM_BUILD_ROOT/usr/bin
cat > $RPM_BUILD_ROOT/usr/bin/obs_productconvert <<EOF
#!/bin/bash
exec /usr/lib/obs/server/bs_productconvert "\$@"
EOF
chmod 0755 $RPM_BUILD_ROOT/usr/bin/obs_productconvert
cat > $RPM_BUILD_ROOT/usr/sbin/obs_admin <<EOF
#!/bin/bash
exec /usr/lib/obs/server/bs_admin "\$@"
EOF
chmod 0755 $RPM_BUILD_ROOT/usr/sbin/obs_admin
cat > $RPM_BUILD_ROOT/usr/sbin/obs_serverstatus <<EOF
#!/bin/bash
exec /usr/lib/obs/server/bs_serverstatus "\$@"
EOF
chmod 0755 $RPM_BUILD_ROOT/usr/sbin/obs_serverstatus

#
# Install all web and api parts.
#
cd ../src
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/
cp -a api $RPM_BUILD_ROOT/srv/www/obs/api
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/api/log
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/api/tmp
touch $RPM_BUILD_ROOT/srv/www/obs/api/log/production.log
# the git webinterface tries to connect to api.opensuse.org by default
#install -m 0644 ../dist/webui-production.rb $RPM_BUILD_ROOT/srv/www/obs/webui/config/environments/production.rb
# prepare for running sphinx daemon
install -m 0755 -d $RPM_BUILD_ROOT/srv/www/obs/api/db/sphinx{,/production}

#
# install apidocs
# 
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/docs
cp -a ../docs/api/api    $RPM_BUILD_ROOT/srv/www/obs/docs/
cp -a ../docs/api/html   $RPM_BUILD_ROOT/srv/www/obs/docs/api/
ln -sf /srv/www/obs/docs/api $RPM_BUILD_ROOT/srv/www/obs/api/public/schema

echo 'CONFIG["apidocs_location"] ||= File.expand_path("../docs/api/html/")' >> $RPM_BUILD_ROOT/srv/www/obs/api/config/environment.rb
echo 'CONFIG["schema_location"] ||= File.expand_path("../docs/api/")' >> $RPM_BUILD_ROOT/srv/www/obs/api/config/environment.rb

#
# Install all backend parts.
#
cd backend/
# we use external build script code
rm -rf build
cp BSConfig.pm.template BSConfig.pm

install -d -m 755 $RPM_BUILD_ROOT/usr/lib/obs/server/
ln -sf /usr/lib/build $RPM_BUILD_ROOT/usr/lib/obs/server/build # just for check section, it is a %%ghost
#for i in build events info jobs log projects repos run sources trees workers; do
#  install -d -m 755 $RPM_BUILD_ROOT/srv/obs/$i
#done
# install executables and code
cp -a * $RPM_BUILD_ROOT/usr/lib/obs/server/
rm -r   $RPM_BUILD_ROOT/usr/lib/obs/server/testdata
cd ..

#
# turn duplicates into hard links
#
# There's dupes between webui and api:
%if 0%{?suse_version} >= 1030
%fdupes $RPM_BUILD_ROOT/srv/www/obs
%endif

# no more lighttpd
rm $RPM_BUILD_ROOT/srv/www/obs/api/config/lighttpd.conf

# these config files must not be hard linked
install api/config/database.yml.example $RPM_BUILD_ROOT/srv/www/obs/api/config/database.yml
install api/config/options.yml.example $RPM_BUILD_ROOT/srv/www/obs/api/config/options.yml
install api/config/thinking_sphinx.yml.example $RPM_BUILD_ROOT/srv/www/obs/api/config/thinking_sphinx.yml

for file in api/log/access.log api/log/backend_access.log api/log/delayed_job.log api/log/error.log api/log/lastevents.access.log; do
  touch $RPM_BUILD_ROOT/srv/www/obs/$file
done

pushd $RPM_BUILD_ROOT/srv/www/obs/api
# we need to have *something* as secret key
echo "" | sha256sum| cut -d\  -f 1 > config/secret.key
bundle exec rake --trace assets:precompile RAILS_ENV=production RAILS_GROUPS=assets
rm -rf tmp/cache/sass tmp/cache/assets config/secret.key
export BUNDLE_WITHOUT=test:assets:development
export BUNDLE_FROZEN=1
bundle config --local frozen 1
bundle config --local without test:assets:development 
# reinstall
install config/database.yml.example config/database.yml
: > log/production.log
sed -i -e 's,^api_version.*,api_version = "%version",' config/initializers/02_apiversion.rb
popd

mkdir -p %{buildroot}%{_docdir}
cat > %{buildroot}%{_docdir}/README.devel <<EOF
This package does not contain any development files. But it helps you start with 
git development - look at http://github.com/opensuse/open-build-service
EOF

%check
# check installed backend
pushd $RPM_BUILD_ROOT/usr/lib/obs/server/
file build
rm build
ln -sf /usr/lib/build build # just for %%check, it is a %%ghost
for i in bs_*; do
  perl -wc "$i"
done
popd

# run in build environment
pushd src/backend/
rm -rf build
ln -sf /usr/lib/build build
popd
# setup mysqld
rm -rf /tmp/obs.mysql.db /tmp/obs.test.mysql.socket
mysql_install_db --user=`whoami` --datadir="/tmp/obs.mysql.db"
/usr/sbin/mysqld --datadir=/tmp/obs.mysql.db -P 54321 --socket=/tmp/obs.test.mysql.socket &
sleep 2
##################### api
pushd src/api/
# setup files
cp config/options.yml{.example,}
cp config/thinking_sphinx.yml{.example,}
touch config/test.sphinx.conf
cat > config/database.yml <<EOF
test:
  adapter: mysql2
  host:    localhost
  database: api_test
  username: root
  encoding: utf8
  socket:   /tmp/obs.test.mysql.socket
EOF
export RAILS_ENV=test
/usr/sbin/memcached -l 127.0.0.1 -d -P $PWD/memcached.pid
bundle exec rake --trace db:create db:setup || exit 1
mv log/test.log{,.old}
if ! bundle exec rake --trace test:api test:webui; then
  cat log/test.log
  kill $(cat memcached.pid)
  exit 1
fi
kill $(cat memcached.pid) || :
popd

#cleanup
/usr/bin/mysqladmin -u root --socket=/tmp/obs.test.mysql.socket shutdown || true
rm -rf /tmp/obs.mysql.db /tmp/obs.test.mysql.socket

%pre
getent group obsrun >/dev/null || groupadd -r obsrun
getent passwd obsrun >/dev/null || \
    /usr/sbin/useradd -r -g obsrun -d /usr/lib/obs -s %{sbin}/nologin \
    -c "User for build service backend" obsrun
exit 0

%pre -n obs-worker
getent group obsrun >/dev/null || groupadd -r obsrun
getent passwd obsrun >/dev/null || \
    /usr/sbin/useradd -r -g obsrun -d /usr/lib/obs -s %{sbin}/nologin \
    -c "User for build service backend" obsrun
exit 0

%preun
%stop_on_removal obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher obswarden obssigner

%preun -n obs-worker
%stop_on_removal obsworker

%post
[ -d /srv/obs ] || install -d -o obsrun -g obsrun /srv/obs
%{fillup_and_insserv -n obs-server}
%restart_on_update obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher obswarden obssigner

%preun -n obs-source_service
%stop_on_removal obsservice

%post -n obs-source_service
%restart_on_update obsservice

%posttrans
# this changes from directory to symlink. rpm can not handle this itself.
if [ -e /usr/lib/obs/server/build -a ! -L /usr/lib/obs/server/build ]; then
  rm -rf /usr/lib/obs/server/build
fi
if [ ! -e /usr/lib/obs/server/build ]; then
  ln -sf ../../build /usr/lib/obs/server/build
fi

%postun
%insserv_cleanup
%verifyscript -n obs-server
%verify_permissions
# cleanup empty directory just in case
rmdir /srv/obs 2> /dev/null || :

%post -n obs-worker
%{fillup_and_insserv -n obs-server}
# NOT used on purpose: restart_on_update obsworker
# This can cause problems when building chroot
# and bs_worker is anyway updating itself at runtime based on server code

%pre -n obs-api
getent passwd obsapidelayed >/dev/null || \
  /usr/sbin/useradd -r -s /bin/bash -c "User for build service api delayed jobs" -d /srv/www/obs/api -g www obsapidelayed

%post -n obs-api
%{fillup_and_insserv -n obs-server}
if [ -e /srv/www/obs/frontend/config/database.yml ] && [ ! -e /srv/www/obs/api/config/database.yml ]; then
  cp /srv/www/obs/frontend/config/database.yml /srv/www/obs/api/config/database.yml
fi
for i in production.rb ; do
  if [ -e /srv/www/obs/frontend/config/environments/$i ] && [ ! -e /srv/www/obs/api/config/environments/$i ]; then
    cp /srv/www/obs/frontend/config/environments/$i /srv/www/obs/api/config/environments/$i
  fi
done
SECRET_KEY="/srv/www/obs/api/config/secret.key"
if [ ! -e "$SECRET_KEY" ]; then
  ( umask 0077; dd if=/dev/urandom bs=256 count=1 2>/dev/null |sha256sum| cut -d\  -f 1 >$SECRET_KEY )
fi
chmod 0640 $SECRET_KEY
chown root.www $SECRET_KEY
# update config
sed -i -e 's,[ ]*adapter: mysql$,  adapter: mysql2,' /srv/www/obs/api/config/database.yml

%restart_on_update apache2
%restart_on_update obsapisetup
%restart_on_update obsapidelayed

%postun -n obs-api
%insserv_cleanup

%files
%defattr(-,root,root)
%doc dist/{README.UPDATERS,README.SETUP} docs/openSUSE.org.xml ReleaseNotes-* README.md COPYING AUTHORS
%dir /etc/slp.reg.d
%dir /usr/lib/obs
%dir /usr/lib/obs/server
/etc/logrotate.d/obs-server
/etc/init.d/obsdispatcher
/etc/init.d/obspublisher
/etc/init.d/obsrepserver
/etc/init.d/obsscheduler
/etc/init.d/obssrcserver
/etc/init.d/obswarden
/etc/init.d/obssigner
/usr/sbin/obs_admin
/usr/sbin/obs_serverstatus
/usr/sbin/rcobsdispatcher
/usr/sbin/rcobspublisher
/usr/sbin/rcobsrepserver
/usr/sbin/rcobsscheduler
/usr/sbin/rcobssrcserver
/usr/sbin/rcobswarden
/usr/sbin/rcobssigner
/usr/lib/obs/server/plugins
/usr/lib/obs/server/BSAccess.pm
/usr/lib/obs/server/BSBuild.pm
/usr/lib/obs/server/BSCando.pm
/usr/lib/obs/server/BSConfiguration.pm
/usr/lib/obs/server/BSConfig.pm.template
/usr/lib/obs/server/BSEvents.pm
/usr/lib/obs/server/BSFileDB.pm
/usr/lib/obs/server/BSHTTP.pm
/usr/lib/obs/server/BSHandoff.pm
/usr/lib/obs/server/BSNotify.pm
/usr/lib/obs/server/BSRPC.pm
/usr/lib/obs/server/BSServer.pm
/usr/lib/obs/server/BSServerEvents.pm
/usr/lib/obs/server/BSSrcdiff.pm
/usr/lib/obs/server/BSSSL.pm
/usr/lib/obs/server/BSStdServer.pm
/usr/lib/obs/server/BSUtil.pm
/usr/lib/obs/server/BSVerify.pm
/usr/lib/obs/server/BSDB.pm
/usr/lib/obs/server/BSDBIndex.pm
/usr/lib/obs/server/BSXPathKeys.pm
/usr/lib/obs/server/BSWatcher.pm
/usr/lib/obs/server/BSXML.pm
/usr/lib/obs/server/BSXPath.pm
/usr/lib/obs/server/BSProductXML.pm
/usr/lib/obs/server/BSKiwiXML.pm
%dir /usr/lib/obs/server/Meta
/usr/lib/obs/server/Meta.pm
/usr/lib/obs/server/Meta/Debmd.pm
/usr/lib/obs/server/Meta/Rpmmd.pm
/usr/lib/obs/server/Meta/Susetagsmd.pm
/usr/lib/obs/server/DESIGN
/usr/lib/obs/server/License
/usr/lib/obs/server/README
/usr/lib/obs/server/XML
/usr/lib/obs/server/bs_admin
/usr/lib/obs/server/bs_archivereq
/usr/lib/obs/server/bs_check_consistency
/usr/lib/obs/server/bs_getbinariesproxy
/usr/lib/obs/server/bs_mkarchrepo
/usr/lib/obs/server/bs_dispatch
/usr/lib/obs/server/bs_publish
/usr/lib/obs/server/bs_repserver
/usr/lib/obs/server/bs_sched
/usr/lib/obs/server/bs_serverstatus
/usr/lib/obs/server/bs_srcserver
/usr/lib/obs/server/bs_worker
/usr/lib/obs/server/bs_signer
/usr/lib/obs/server/bs_sshgit
/usr/lib/obs/server/bs_warden
/usr/lib/obs/server/worker
/usr/lib/obs/server/worker-deltagen.spec
%config(noreplace) /usr/lib/obs/server/BSConfig.pm
%config(noreplace) /etc/slp.reg.d/*
# created via %%post, since rpm fails otherwise while switching from 
# directory to symlink
%ghost /usr/lib/obs/server/build

%files -n obs-source_service
%defattr(-,root,root)
/etc/init.d/obsservice
/usr/sbin/rcobsservice
/usr/lib/obs/server/bs_service
/usr/lib/obs/server/call-service-in-lxc.sh

%files -n obs-worker
%defattr(-,root,root)
/var/adm/fillup-templates/sysconfig.obs-server
/etc/init.d/obsworker
/etc/init.d/obsstoragesetup
/usr/sbin/rcobsworker
/usr/sbin/rcobsstoragesetup

%files -n obs-api
%defattr(-,root,root)
%doc dist/{README.UPDATERS,README.SETUP} docs/openSUSE.org.xml ReleaseNotes-* README.md COPYING AUTHORS
/srv/www/obs/overview

/srv/www/obs/api/config/thinking_sphinx.yml.example
%config(noreplace) /srv/www/obs/api/config/thinking_sphinx.yml

%dir /srv/www/obs
%dir /srv/www/obs/api
%dir /srv/www/obs/api/config
/srv/www/obs/api/config/initializers
%dir /srv/www/obs/api/config/environments
%dir /srv/www/obs/api/files
/srv/www/obs/api/.simplecov
/srv/www/obs/api/Gemfile
/srv/www/obs/api/Gemfile.lock
/srv/www/obs/api/config.ru
/srv/www/obs/api/config/application.rb
/srv/www/obs/api/config/clock.rb
/etc/logrotate.d/obs-build
/etc/logrotate.d/obs-api
/etc/init.d/obsapidelayed
/etc/init.d/obsapisetup
/usr/sbin/rcobsapisetup
/usr/sbin/rcobsapidelayed
/srv/www/obs/api/app
/srv/www/obs/api/db
/srv/www/obs/api/files/wizardtemplate.spec
/srv/www/obs/api/lib
/srv/www/obs/api/public
/srv/www/obs/api/Rakefile
/srv/www/obs/api/script
/srv/www/obs/api/bin
/srv/www/obs/api/test
/srv/www/obs/docs

# starting the webui part
/srv/www/obs/api/webui/
%dir /srv/www/obs/api/config
/srv/www/obs/api/config/locales
%dir /srv/www/obs/api/vendor
/srv/www/obs/api/vendor/diststats

#
# some files below config actually are _not_ config files
# so here we go, file by file
#

/srv/www/obs/api/config/boot.rb
/srv/www/obs/api/config/routes.rb
/srv/www/obs/api/config/environments/development.rb
/srv/www/obs/api/config/unicorn
%attr(0640,root,%apache_group) %config(noreplace) /srv/www/obs/api/config/database.yml*
%attr(0644,root,root) %config(noreplace) /srv/www/obs/api/config/options.yml*
%dir %attr(0755,%apache_user,%apache_group) /srv/www/obs/api/db/sphinx
%dir %attr(0755,%apache_user,%apache_group) /srv/www/obs/api/db/sphinx/production
/srv/www/obs/api/.bundle

%config /srv/www/obs/api/config/environment.rb
%config /srv/www/obs/api/config/environments/production.rb
%config /srv/www/obs/api/config/environments/test.rb
%config /srv/www/obs/api/config/environments/stage.rb
%config(noreplace) /srv/www/obs/api/config/active_rbac_config.rb

%dir %attr(-,%{apache_user},%{apache_group}) /srv/www/obs/api/log
%verify(not size md5) %attr(-,%{apache_user},%{apache_group}) /srv/www/obs/api/log/production.log
%attr(-,%{apache_user},%{apache_group}) /srv/www/obs/api/tmp

# these dirs primarily belong to apache2:
%dir /etc/apache2
%dir /etc/apache2/vhosts.d
%config(noreplace) /etc/apache2/vhosts.d/obs.conf

%ghost /srv/www/obs/api/log/access.log
%ghost /srv/www/obs/api/log/backend_access.log
%ghost /srv/www/obs/api/log/delayed_job.log
%ghost /srv/www/obs/api/log/error.log
%ghost /srv/www/obs/api/log/lastevents.access.log

%files -n obs-utils
%defattr(-,root,root)
/usr/sbin/obs_mirror_project
/usr/sbin/obs_project_update

%files -n obs-productconverter
%defattr(-,root,root)
/usr/bin/obs_productconvert
/usr/lib/obs/server/bs_productconvert

%files -n obs-devel
%defattr(-,root,root)
%_docdir/README.devel

%changelog
