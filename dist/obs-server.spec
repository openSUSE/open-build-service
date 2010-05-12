#
# spec file for package obs-server
#
# Copyright (c) 2008 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#



Name:           obs-server
Summary:        The openSUSE Build Service -- Server Component

Version:        1.9.62
Release:        0
License:        GPL
Group:          Productivity/Networking/Web/Utilities
Url:            http://en.opensuse.org/Build_Service
BuildRoot:      /var/tmp/%name-root
# git clone git://gitorious.org/opensuse/build-service.git build-service-1.7.54; tar cfvj obs-server-1.7.54.tar.bz2 --exclude=.git\* build-service-1.7.54/
Source:         obs-server-%version.tar.bz2
# git clone git://gitorious.org/opensuse/themes.git opensuse-themes-0.9; tar cfvj opensuse-themes-0.9.tar.bz2 --exclude=.git\* opensuse-themes-0.9
Source1:        opensuse-themes-0.9.tar.bz2
Autoreqprov:    on
BuildRequires:  python-devel
BuildRequires:  obs-common
# make sure this is in sync with the RAILS_GEM_VERSION specified in the
# config/environment.rb of the various applications.
# atm the obs rails version patch above unifies that setting among the applications
# also see requires in the obs-server-api sub package
BuildRequires:  rubygem-rails-2_3 = 2.3.5
BuildRequires:  rubygem-rmagick
BuildRequires:  build >= 2009.05.04
BuildRequires:  perl-BSSolv
BuildRequires:  lighttpd
Requires:       build >= 2009.05.04
Requires:       perl-BSSolv
# Required by source server
Requires:       patch diffutils
PreReq:         sysvinit

%if 0%{?suse_version} >= 1030
BuildRequires:  fdupes
%endif
%if 0%{?suse_version:1}
PreReq:         %fillup_prereq %insserv_prereq permissions
%endif

%if 0%{?suse_version} >= 1020
Recommends:     yum yum-metadata-parser repoview dpkg
Recommends:     createrepo
Conflicts:      createrepo < 0.9.8
Recommends:     deb >= 1.5
Recommends:     lvm2
Recommends:     openslp-server
Recommends:     obs-signd
%else
Requires:       yum yum-metadata-parser dpkg
Requires:       createrepo >= 0.4.10
%endif
Requires:       perl-Compress-Zlib perl-Net_SSLeay perl-Socket-MsgHdr perl-XML-Parser

%description
Authors:
--------
    The openSUSE Team <opensuse-buildservice@opensuse.org>

%package -n obs-worker
Requires:	perl-TimeDate screen curl perl-XML-Parser perl-Compress-Zlib cpio
# For runlevel script:
Requires:       curl
Recommends:     openslp lvm2
# requires from build script
Requires:       bash binutils
Summary:        The openSUSE Build Service -- Build Host Component
Group:          Productivity/Networking/Web/Utilities
%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif
%if 0%{?suse_version} <= 1030
Requires:       lzma
%endif
%if 0%{?suse_version} >= 1120
BuildArch:      noarch
Requires:	util-linux >= 2.16
%else
%ifarch x86_64
Requires:	linux32
%endif
%ifarch ppc64
Requires:	powerpc32
%endif
%endif

%description -n obs-worker
This is the obs build host, to be installed on each machine building
packages in this obs installation.  Install it alongside obs-server to
run a local playground test installation.

%package -n obs-api
Summary:        The openSUSE Build Service -- The Frontend part
Group:          Productivity/Networking/Web/Utilities
Requires:       obs-common
%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif

Requires:       lighttpd ruby-fcgi lighttpd-mod_magnet mysql ruby-mysql
# make sure this is in sync with the RAILS_GEM_VERSION specified in the
# config/environment.rb of the various applications.
Requires:       rubygem-rails-2_3 = 2.3.5
Requires:       rubygem-libxml-ruby
Requires:       rubygem-daemons
Requires:       rubygem-delayed_job
%if 0%{?suse_version} >= 1020
Supplements:    ruby-ldap
%endif
# requires for webui:
Requires:       ghostscript-fonts-std
Requires:       rubygem-gruff
Requires:       rubygem-sqlite3
Requires:       rubygem-rmagick
Requires:       rubygem-exception_notification
Recommends:     memcached
Group:          Productivity/Networking/Web/Utilities
Summary:        The openSUSE Build Service -- The Frontend part

%description -n obs-api
This is the API server instance, and the web client for the 
OBS.

%package -n obs-source_service
Summary:        The openSUSE Build Service -- source service daemon
Group:          Productivity/Networking/Web/Utilities

%description -n obs-source_service
The OBS source service is a component to modify submitted sources
on the server side. This may include source checkout, spec file
generation, gpg validation, quality checks and other stuff.

This component is optional and not required to run the service.


%package -n obs-productconverter
Summary:        The openSUSE Build Service -- product definition utility
Group:          Productivity/Networking/Web/Utilities
# For perl library files, TODO: split out obs-lib subpackage?
Requires:       obs-server

%description -n obs-productconverter
bs_productconvert is a utility to create Kiwi- and Spec- files from a
product definition.

%package -n obs-utils
Summary:        The openSUSE Build Service -- utilities
Group:          Productivity/Networking/Web/Utilities
Requires:       osc build ruby 

%description -n obs-utils
obs_mirror_project is a tool to copy the binary data of a project from one obs to another
obs_project_update is a tool to copy a packages of a project from one obs to another

Authors:       Susanne Oberhauser, Martin Mohring

#--------------------------------------------------------------------------------
%prep
%setup -q -n build-service-%version -b 1
# drop build script, we require the installed one from own package
rm -rf src/build
find . -name .git\* -o -name Capfile -o -name deploy.rb | xargs rm -rf

%build
#
# generate apidocs
#
cd docs/api/api
make apidocs
cd -

%install
#
# First install all dist files
#
cd dist
# configure lighttpd web service
mkdir -p $RPM_BUILD_ROOT/etc/lighttpd/vhosts.d/
install -m 0644 obs.conf $RPM_BUILD_ROOT/etc/lighttpd/vhosts.d/
install -m 0644 rails.include $RPM_BUILD_ROOT/etc/lighttpd/vhosts.d/rails.inc
install -m 0644 cleanurl-v5.lua $RPM_BUILD_ROOT/etc/lighttpd/
# install obs mirror script and obs copy script
install -d -m 755 $RPM_BUILD_ROOT/usr/sbin/
install -m 0755 obs_mirror_project obs_project_update $RPM_BUILD_ROOT/usr/sbin/
# install  runlevel scripts
install -d -m 755 $RPM_BUILD_ROOT/etc/init.d/
for i in obssrcserver obsrepserver obsscheduler obsworker obspublisher obsdispatcher \
         obssigner obswarden obsapidelayed obswebuidelayed obsapisetup obsstoragesetup \
         obsservice; do
  install -m 0755 $i \
           $RPM_BUILD_ROOT/etc/init.d/
  ln -sf /etc/init.d/$i $RPM_BUILD_ROOT/usr/sbin/rc$i
done
# install logrotate
install -d -m 755 $RPM_BUILD_ROOT/etc/logrotate.d/
for i in obs-api.logrotate obs-build.logrotate obs-server.logrotate ; do
  install -m 0755 $i \
           $RPM_BUILD_ROOT/etc/logrotate.d/
done
# install fillups
FILLUP_DIR=$RPM_BUILD_ROOT/var/adm/fillup-templates
install -d -m 755 $FILLUP_DIR
install -m 0644 sysconfig.obs-server sysconfig.obs-worker $FILLUP_DIR/
# install cronjobs
CRON_DIR=$RPM_BUILD_ROOT/etc/cron.d
install -d -m 755 $CRON_DIR
install -m 0644 crontab.obs-api   $CRON_DIR/obs-api
install -m 0644 crontab.obs-webui $CRON_DIR/obs-webui
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


#
# Install all web and api parts.
#
cd ../src
for i in api webui; do
  mkdir -p $RPM_BUILD_ROOT/srv/www/obs/
  cp -a $i $RPM_BUILD_ROOT/srv/www/obs/$i
done
rm $RPM_BUILD_ROOT/srv/www/obs/api/README_LOGIN
rm $RPM_BUILD_ROOT/srv/www/obs/api/files/specfiletemplate
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/api/log
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/webui/log
touch $RPM_BUILD_ROOT/srv/www/obs/{webui,api}/log/production.log
rm $RPM_BUILD_ROOT/srv/www/obs/webui/README.install
# the git webinterface tries to connect to api.opensuse.org by default
install -m 0644 ../dist/webui-production.rb $RPM_BUILD_ROOT/srv/www/obs/webui/config/environments/production.rb
# needed for correct permissions
touch $RPM_BUILD_ROOT/srv/www/obs/webui/db/database.db

#
#set default api on localhost for the webui
# 
mv $RPM_BUILD_ROOT/srv/www/obs/api/files/distributions.xml.template $RPM_BUILD_ROOT/srv/www/obs/api/files/distributions.xml
sed 's,FRONTEND_HOST.*,FRONTEND_HOST = "127.0.42.2",' \
  $RPM_BUILD_ROOT/srv/www/obs/webui/config/environments/development.rb > tmp-file \
  && mv tmp-file "$RPM_BUILD_ROOT/srv/www/obs/webui/config/environments/development.rb"
sed 's,FRONTEND_PORT.*,FRONTEND_PORT = 80,' \
  $RPM_BUILD_ROOT/srv/www/obs/webui/config/environments/development.rb > tmp-file \
  && mv tmp-file "$RPM_BUILD_ROOT/srv/www/obs/webui/config/environments/development.rb"
sed 's,api.opensuse.org,127.0.42.2,' \
  $RPM_BUILD_ROOT/srv/www/obs/webui/app/helpers/package_helper.rb > tmp-file \
  && mv tmp-file "$RPM_BUILD_ROOT/srv/www/obs/webui/app/helpers/package_helper.rb"

#
# Install webui theme
#
mkdir -p "$RPM_BUILD_ROOT/srv/www/obs/webui/public/themes/"
cp -av "$RPM_BUILD_DIR"/opensuse-themes-*/* "$RPM_BUILD_ROOT/srv/www/obs/webui/public/themes/"

#
# install apidocs
# 
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/api/public/apidocs/html/
cp -a ../docs/api/html           $RPM_BUILD_ROOT/srv/www/obs/api/public/apidocs
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/docs/api
cp -a ../docs/api/api/*.{rng,xsd}    $RPM_BUILD_ROOT/srv/www/obs/docs/api
#
# Fix symlinks to common, could be much cleaner ...
#
rm -f $RPM_BUILD_ROOT/srv/www/obs/api/lib/common $RPM_BUILD_ROOT/srv/www/obs/webui/lib/common
ln -sf /srv/www/obs/common/lib $RPM_BUILD_ROOT/srv/www/obs/api/lib/common
ln -sf /srv/www/obs/common/lib $RPM_BUILD_ROOT/srv/www/obs/webui/lib/common
ln -sf /srv/www/obs/common/images $RPM_BUILD_ROOT/srv/www/obs/api/public/images/common
ln -sf /srv/www/obs/common/images $RPM_BUILD_ROOT/srv/www/obs/webui/public/images/common
ln -sf /srv/www/obs/docs/api $RPM_BUILD_ROOT/srv/www/obs/api/public/schema
#
# change script names to allow to start them with startproc
#
mv $RPM_BUILD_ROOT/srv/www/obs/api/script/delayed_job{,.api}
mv $RPM_BUILD_ROOT/srv/www/obs/webui/script/delayed_job{,.web}

#
# Install all backend parts.
#
cd backend/
# we use external build script code
rm -rf build
cp BSConfig.pm.template BSConfig.pm

install -d -m 755 $RPM_BUILD_ROOT/usr/lib/obs/server/
install -d -m 755 $RPM_BUILD_ROOT/usr/lib/obs/server/build # dummy, it is a %ghost
install -d -m 755 $RPM_BUILD_ROOT/srv/obs/log
install -d -m 755 $RPM_BUILD_ROOT/srv/obs/run
# install executables and code
cp -a * $RPM_BUILD_ROOT/usr/lib/obs/server/
rm -r   $RPM_BUILD_ROOT/usr/lib/obs/server/testdata
rm      $RPM_BUILD_ROOT/usr/lib/obs/server/Makefile.PL
# create symlink to build scritps
#rm -rf $RPM_BUILD_ROOT/usr/lib/obs/server/build
#ln -sf /usr/lib/build $RPM_BUILD_ROOT/usr/lib/obs/server/build

#
# turn duplicates into hard links
#
#%fdupes $RPM_BUILD_ROOT/srv/www/obs/api
#%fdupes $RPM_BUILD_ROOT/srv/www/obs/webui
# There's dupes between webui and api:
%if 0%{?suse_version} >= 1030
%fdupes $RPM_BUILD_ROOT/srv/www/obs
%endif

%pre
/usr/sbin/groupadd -r obsrun 2> /dev/null || :
/usr/sbin/useradd -r -o -s /bin/false -c "User for build service backend" -d /usr/lib/obs -g obsrun obsrun 2> /dev/null || :

%pre -n obs-worker
/usr/sbin/groupadd -r obsrun 2> /dev/null || :
/usr/sbin/useradd -r -o -s /bin/false -c "User for build service backend" -d /usr/lib/obs -g obsrun obsrun 2> /dev/null || :

%preun
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher obswarden obssigner obsstoragesetup ; do
%stop_on_removal $service
done

%preun -n obs-worker
%stop_on_removal obsworker

%post
%run_permissions
%{fillup_and_insserv -n obs-server}
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher obswarden obssigner obsstoragesetup ; do
%restart_on_update $service
done

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

%post -n obs-worker
%{fillup_and_insserv -n obs-worker}
%restart_on_update obsworker

%post -n obs-api
%{fillup_and_insserv -n obs-server}
if [ -e /srv/www/obs/webclient/config/database.yml ] && [ ! -e /srv/www/obs/webui/config/database.yml ]; then
  cp /srv/www/obs/webclient/config/database.yml /srv/www/obs/webui/config/database.yml
fi
if [ -e /srv/www/obs/frontend/config/database.yml ] && [ ! -e /srv/www/obs/api/config/database.yml ]; then
  cp /srv/www/obs/frontend/config/database.yml /srv/www/obs/api/config/database.yml
fi
# updaters can keep their production_slave config
for i in production_slave.rb production.rb development_base.rb; do
  if [ -e /srv/www/obs/webclient/config/environments/$i ] && [ ! -e /srv/www/obs/webui/config/environments/$i ]; then
    cp /srv/www/obs/webclient/config/environments/$i /srv/www/obs/webui/config/environments/$i
  fi
  if [ -e /srv/www/obs/frontend/config/environments/$i ] && [ ! -e /srv/www/obs/api/config/environments/$i ]; then
    cp /srv/www/obs/frontend/config/environments/$i /srv/www/obs/api/config/environments/$i
  fi
done
if [ -e /etc/lighttpd/vhosts.d/obs.conf ]; then
  sed -i -e 's,/srv/www/obs/webclient,/srv/www/obs/webui,' \
	 -e 's,/srv/www/obs/frontend,/srv/www/obs/api,' \
	 /etc/lighttpd/vhosts.d/obs.conf
fi
echo '**** Keep in mind to run rake db:migrate after updating this package (read README.UPDATERS) ****'
%restart_on_update lighttpd

%postun -n obs-api
%insserv_cleanup

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%dir /etc/slp.reg.d
%dir /usr/lib/obs
%dir /usr/lib/obs/server
/etc/logrotate.d/obs-server.logrotate
/etc/init.d/obsdispatcher
/etc/init.d/obspublisher
/etc/init.d/obsrepserver
/etc/init.d/obsscheduler
/etc/init.d/obssrcserver
/etc/init.d/obswarden
/etc/init.d/obssigner
/etc/init.d/obsstoragesetup
/usr/sbin/obs_admin
/usr/sbin/rcobsdispatcher
/usr/sbin/rcobspublisher
/usr/sbin/rcobsrepserver
/usr/sbin/rcobsscheduler
/usr/sbin/rcobssrcserver
/usr/sbin/rcobswarden
/usr/sbin/rcobssigner
/usr/sbin/rcobsstoragesetup
/usr/lib/obs/server/BSAccess.pm
/usr/lib/obs/server/BSBuild.pm
/usr/lib/obs/server/BSConfig.pm.template
/usr/lib/obs/server/BSEvents.pm
/usr/lib/obs/server/BSFileDB.pm
/usr/lib/obs/server/BSHTTP.pm
/usr/lib/obs/server/BSHandoff.pm
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
/usr/lib/obs/server/COPYING
/usr/lib/obs/server/DESIGN
/usr/lib/obs/server/License
/usr/lib/obs/server/README
/usr/lib/obs/server/TODO
/usr/lib/obs/server/XML
/usr/lib/obs/server/bs_admin
/usr/lib/obs/server/bs_dispatch
/usr/lib/obs/server/bs_publish
/usr/lib/obs/server/bs_repserver
/usr/lib/obs/server/bs_sched
/usr/lib/obs/server/bs_srcserver
/usr/lib/obs/server/bs_worker
/usr/lib/obs/server/bs_signer
/usr/lib/obs/server/bs_sshgit
/usr/lib/obs/server/bs_warden
/usr/lib/obs/server/worker
/usr/lib/obs/server/BSHermes.pm
/usr/lib/obs/server/BSSolv.pm
/usr/lib/obs/server/BSSolv.xs
/usr/lib/obs/server/typemap
%config(noreplace) /usr/lib/obs/server/BSConfig.pm
%config(noreplace) /etc/slp.reg.d/*
%attr(-,obsrun,obsrun) /srv/obs
/var/adm/fillup-templates/sysconfig.obs-server
# created via %post, since rpm fails otherwise while switching from 
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
/var/adm/fillup-templates/sysconfig.obs-worker
/etc/init.d/obsworker
/etc/init.d/obsstoragesetup
/usr/sbin/rcobsworker
/usr/sbin/rcobsstoragesetup
# intentionally packaged in server and api package
/var/adm/fillup-templates/sysconfig.obs-server

%files -n obs-api
%defattr(-,root,root)
%doc dist/{TODO,README.UPDATERS,README.SETUP} docs/openSUSE.org.xml ReleaseNotes-* README COPYING
%dir /srv/www/obs
%dir /srv/www/obs/api
%dir /srv/www/obs/api/config
%dir /srv/www/obs/api/config/initializers
%dir /srv/www/obs/api/config/environments
%dir /srv/www/obs/api/files
/etc/logrotate.d/obs-build.logrotate
/etc/logrotate.d/obs-api.logrotate
/etc/init.d/obsapidelayed
/etc/init.d/obswebuidelayed
/etc/init.d/obsapisetup
/usr/sbin/rcobsapisetup
/usr/sbin/rcobsapidelayed
/usr/sbin/rcobswebuidelayed
/srv/www/obs/api/app
/srv/www/obs/api/db
/srv/www/obs/api/doc
/srv/www/obs/api/files/distributions
/srv/www/obs/api/files/wizardtemplate.spec
/srv/www/obs/api/lib
/srv/www/obs/api/public
/srv/www/obs/api/Rakefile
/srv/www/obs/api/README
/srv/www/obs/api/script
/srv/www/obs/api/test
/srv/www/obs/api/vendor
/srv/www/obs/docs
# intentionally packaged in server and api package
/var/adm/fillup-templates/sysconfig.obs-server

#
# some files below config actually are _not_ config files
# so here we go, file by file
#

/srv/www/obs/api/config/boot.rb
/srv/www/obs/api/config/routes.rb
/srv/www/obs/api/config/environments/development.rb
/srv/www/obs/api/config/database.yml.example
/srv/www/obs/api/config/environments/production_test.rb
/srv/www/obs/api/config/initializers/options.rb

%config /srv/www/obs/api/config/environment.rb
%config(noreplace) /srv/www/obs/api/config/lighttpd.conf
%config(noreplace) /srv/www/obs/api/config/environments/production.rb
%config(noreplace) /srv/www/obs/api/config/environments/test.rb
%config(noreplace) /srv/www/obs/api/config/environments/stage.rb
%config(noreplace) /srv/www/obs/api/config/environments/development_base.rb
%config(noreplace) /srv/www/obs/api/config/active_rbac_config.rb
%config(noreplace) /srv/www/obs/api/config/options.yml
%config(noreplace) /srv/www/obs/api/files/distributions.xml
%config(noreplace) /etc/cron.d/obs-api

%dir %attr(-,lighttpd,lighttpd) /srv/www/obs/api/log
%verify(not size md5) %attr(-,lighttpd,lighttpd) /srv/www/obs/api/log/production.log
%attr(-,lighttpd,lighttpd) /srv/www/obs/api/tmp

# starting the webui part
%dir /srv/www/obs/webui
# sqlite3 needs write permissions
%dir %attr(-,lighttpd,lighttpd) /srv/www/obs/webui/db
/srv/www/obs/webui/app
/srv/www/obs/webui/db/migrate
/srv/www/obs/webui/db/schema.rb
/srv/www/obs/webui/doc
/srv/www/obs/webui/lib
/srv/www/obs/webui/public
/srv/www/obs/webui/Rakefile
/srv/www/obs/webui/script
/srv/www/obs/webui/test
/srv/www/obs/webui/vendor
/srv/www/obs/webui/nbproject

%dir /srv/www/obs/webui/config
%dir /srv/www/obs/webui/config/environments
%dir /srv/www/obs/webui/config/initializers
/srv/www/obs/webui/config/routes.rb
/srv/www/obs/webui/config/environments/development.rb
/srv/www/obs/webui/README.rails
/srv/www/obs/webui/README.theme
/srv/www/obs/webui/config/initializers/options.rb

%config /srv/www/obs/webui/config/boot.rb
%config /srv/www/obs/webui/config/environment.rb
%config(noreplace) /srv/www/obs/webui/config/database.yml
%config(noreplace) /srv/www/obs/webui/config/options.yml
%config(noreplace) /srv/www/obs/webui/config/environments/production.rb
%config(noreplace) /srv/www/obs/webui/config/environments/test.rb
%config(noreplace) /srv/www/obs/webui/config/environments/stage.rb
%config(noreplace) /srv/www/obs/webui/config/environments/development_base.rb
%config(noreplace) /srv/www/obs/webui/config/initializers/theme_support.rb
%config(noreplace) /etc/cron.d/obs-webui

%dir %attr(-,lighttpd,lighttpd) /srv/www/obs/webui/log
%config(noreplace) %verify(not size md5) %attr(-,lighttpd,lighttpd) /srv/www/obs/webui/db/database.db
%config(noreplace) %verify(not size md5) %attr(-,lighttpd,lighttpd) /srv/www/obs/webui/log/production.log
%attr(-,lighttpd,lighttpd) /srv/www/obs/webui/tmp

# these dirs primarily belong to lighttpd:
%config(noreplace) /etc/lighttpd/vhosts.d/obs.conf
%dir /etc/lighttpd
%dir /etc/lighttpd/vhosts.d
%config /etc/lighttpd/cleanurl-v5.lua
%config /etc/lighttpd/vhosts.d/rails.inc

%files -n obs-utils
%defattr(-,root,root)
/usr/sbin/obs_mirror_project
/usr/sbin/obs_project_update

%files -n obs-productconverter
%defattr(-,root,root)
/usr/bin/obs_productconvert
/usr/lib/obs/server/bs_productconvert

%changelog -n obs-server
