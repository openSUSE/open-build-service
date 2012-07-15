#
# spec file for package obs-server
#
# Copyright (c) 2012 SUSE LINUX Products GmbH, Nuernberg, Germany.
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


Name:           obs-server
Summary:        The Open Build Service -- Server Component
License:        GPL-2.0 ; GPL-3.0
Group:          Productivity/Networking/Web/Utilities
Version:        2.3.1
Release:        2
Url:            http://en.opensuse.org/Build_Service
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
# git clone git://gitorious.org/opensuse/build-service.git build-service-1.7.54; tar cfvj obs-server-1.7.54.tar.bz2 --exclude=.git\* build-service-1.7.54/
Source:         obs-server-%version.tar.bz2
# git clone git://gitorious.org/opensuse/themes.git opensuse-themes-0.9; tar cfvj opensuse-themes-0.9.tar.bz2 --exclude=.git\* opensuse-themes-0.9
Source1:        opensuse-themes-%version.tar.bz2
Patch1: 0001-webui-Only-finish-the-http-connection-in-the-error-h.patch
Patch2: 0002-webui-Node-can-have-no-_data-resulting-in-such-messa.patch
Patch3: 0003-webui-buildresult-check-seems-to-need-to-be-explicit.patch
Patch4: 0004-webui-when-_data-is-empty-return-a-suitable-printabl.patch
Patch5: 0005-backend-Add-sb2install-dependancy-handling.patch
#Patch6: 0006-build-Update-build-to-Mer-2012.02.28.patch
Patch7: 0007-dist-Use-.log-instead-of-_log-for-apache-logs-so-the.patch
Patch8: 0008-backend-Force-curl-to-use-no-proxy-to-get-the-bs_wor.patch
Patch9: 0009-backend-Move-project-trees-to-_deleted-when-project-.patch
Patch10: 0010-api-Allow-delayedjob-logging-to-work.patch
Patch11: 0011-backend-Modify-copybuild-so-as-to-shortcircuit-unnec.patch
Patch12: 0012-repserver-Make-prjlinks-a-bit-more-transparent.patch
Patch13: 0013-backend-refactor-prjcopy-code-to-be-faster-and-less-.patch
Patch14: 0014-Revert-changes-to-upstream-copybuild-leave-that-unto.patch
Patch15: 0015-Use-the-copybinary-repo-server-API-Clarify-a-little-.patch

BuildRequires:  python-devel
# make sure this is in sync with the RAILS_GEM_VERSION specified in the
# config/environment.rb of the various applications.
# atm the obs rails version patch above unifies that setting among the applications
# also see requires in the obs-server-api sub package
BuildRequires:  build >= 2012.05.31
BuildRequires:  perl-BSSolv
BuildRequires:  rubygem-rails-2_3 >= 2.3.14
BuildRequires:  rubygem-rmagick
PreReq:         /usr/sbin/useradd /usr/sbin/groupadd
Conflicts:      obs-productconverter < %version-%release
Requires:       build >= 2012.05.31
Requires:       obs-worker
Requires:       perl-BSSolv >= 0.18.0
# Required by source server
Requires:       diffutils
Requires:       patch
PreReq:         sysvinit

%if 0%{?suse_version:1}
BuildRequires:  fdupes
PreReq:         %fillup_prereq %insserv_prereq permissions pwdutils
%endif

%if 0%{?suse_version:1}
Recommends:     yum yum-metadata-parser repoview dpkg
Recommends:     createrepo
Conflicts:      createrepo < 0.9.8
Recommends:     deb >= 1.5
Recommends:     lvm2
Recommends:     openslp-server
Recommends:     obs-signd
Recommends:     inst-source-utils
%else
Requires:       createrepo >= 0.4.10
Requires:       dpkg
Requires:       yum
Requires:       yum-metadata-parser
%endif
Requires:       perl-Compress-Zlib
Requires:       perl-File-Sync >= 0.10
Requires:       perl-Net-SSLeay
Requires:       perl-Socket-MsgHdr
Requires:       perl-XML-Parser

%description
The Open Build Service (OBS) backend is used to store all sources and binaries. It also
calculates the need for new build jobs and distributes it.

Authors:
--------
    The Open Build Service Team <opensuse-buildservice@opensuse.org>

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
#Conflicts:      systemd
# requires from build script
Requires:       bash
Requires:       binutils
Requires:       bsdtar
Summary:        The Open Build Service -- Build Host Component
Group:          Productivity/Networking/Web/Utilities
%if 0%{?suse_version}
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
Group:          Productivity/Networking/Web/Utilities
Obsoletes:      obs-common <= 2.2.90
%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif

#For lighttpd
#Recommends:       lighttpd ruby-fcgi lighttpd-mod_magnet mysql ruby-mysql
#For apache
Recommends:     apache2 apache2-mod_xforward rubygem-passenger-apache2

Requires:       mysql
Requires:       ruby-mysql
# make sure this is in sync with the RAILS_GEM_VERSION specified in the
# config/environment.rb of the various applications.
Requires:       rubygem-ci_reporter
Requires:       rubygem-daemons
Requires:       rubygem-delayed_job < 2.0.0
Requires:       rubygem-json
Requires:       rubygem-libxml-ruby
Requires:       rubygem-rack >= 1.1.0
Requires:       rubygem-rails-2_3 >= 2.3.14
%if 0%{?suse_version} >= 1210
Requires:       rubygem-erubis-2_6
%else
Requires:       rubygem-erubis
%endif
Requires:       rubygem-nokogiri
Requires:       rubygem-rails_xss
%if 0%{?suse_version} >= 1020
Supplements:    ruby-ldap
%endif
# requires for webui:
Requires:       ghostscript-fonts-std
Requires:       rubygem-exception_notification < 2.0
Requires:       rubygem-gruff
Requires:       rubygem-rmagick
Requires:       rubygem-sqlite3
Recommends:     memcached
Summary:        The Open Build Service -- The API and WEBUI
Group:          Productivity/Networking/Web/Utilities

%description -n obs-api
This is the API server instance, and the web client for the 
OBS.

%package -n obs-source_service
Summary:        The Open Build Service -- source service daemon
Group:          Productivity/Networking/Web/Utilities
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
Group:          Productivity/Networking/Web/Utilities
# For perl library files, TODO: split out obs-lib subpackage?
Requires:       obs-server

%description -n obs-productconverter
bs_productconvert is a utility to create Kiwi- and Spec- files from a
product definition.

%package -n obs-utils
Summary:        The Open Build Service -- utilities
Group:          Productivity/Networking/Web/Utilities
Requires:       build
Requires:       osc
Requires:       ruby

%description -n obs-utils
obs_mirror_project is a tool to copy the binary data of a project from one obs to another
obs_project_update is a tool to copy a packages of a project from one obs to another

Authors:       Susanne Oberhauser, Martin Mohring

#--------------------------------------------------------------------------------
%prep
# http://www.rpm.org/max-rpm/s1-rpm-inside-macros.html#S3-RPM-INSIDE-SETUP-MULTI-SOURCE
%setup -T -q -c -n opensuse-themes -a 1
%setup -D -q -n src
%patch1 -p1
%patch2 -p1
%patch3 -p1
%patch4 -p1
%patch5 -p1
#%patch6 -p1
%patch7 -p1
%patch8 -p1
%patch9 -p1
%patch10 -p1
%patch11 -p1
%patch12 -p1
%patch13 -p1
%patch14 -p1
%patch15 -p1
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
# configure apache web service (new default since OBS 2.3)
mkdir -p $RPM_BUILD_ROOT/etc/apache2/vhosts.d/
install -m 0644 obs-apache2.conf $RPM_BUILD_ROOT/etc/apache2/vhosts.d/obs.conf
# configure lighttpd web service (default until OBS 2.1)
mkdir -p $RPM_BUILD_ROOT/etc/lighttpd/vhosts.d/
install -m 0644 obs-lighttpd.conf $RPM_BUILD_ROOT/etc/lighttpd/vhosts.d/obs.conf
install -m 0644 rails.include $RPM_BUILD_ROOT/etc/lighttpd/vhosts.d/rails.inc
install -m 0644 cleanurl-v5.lua $RPM_BUILD_ROOT/etc/lighttpd/
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
# install cronjobs
CRON_DIR=$RPM_BUILD_ROOT/etc/cron.d
install -d -m 755 $CRON_DIR
install -m 0644 crontab.obs-api   $CRON_DIR/obs-api
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
for i in api webui; do
  mkdir -p $RPM_BUILD_ROOT/srv/www/obs/
  cp -a $i $RPM_BUILD_ROOT/srv/www/obs/$i
  rm $RPM_BUILD_ROOT/srv/www/obs/$i/lib/activexml
  mkdir $RPM_BUILD_ROOT/srv/www/obs/$i/lib/activexml
  cp -a activexml/* $RPM_BUILD_ROOT/srv/www/obs/$i/lib/activexml/
done
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/api/log
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/api/tmp
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/webui/log
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/webui/tmp
touch $RPM_BUILD_ROOT/srv/www/obs/{webui,api}/log/production.log
# the git webinterface tries to connect to api.opensuse.org by default
install -m 0644 ../dist/webui-production.rb $RPM_BUILD_ROOT/srv/www/obs/webui/config/environments/production.rb
# needed for correct permissions in case sqlite3 is used
touch $RPM_BUILD_ROOT/srv/www/obs/webui/db/database.db

#
#set default api on localhost for the webui
# 
mv $RPM_BUILD_ROOT/srv/www/obs/api/files/distributions.xml.template $RPM_BUILD_ROOT/srv/www/obs/api/files/distributions.xml
sed -i 's,FRONTEND_HOST.*,FRONTEND_HOST = "127.0.42.2",' \
  $RPM_BUILD_ROOT/srv/www/obs/webui/config/environments/development.rb
sed -i 's,FRONTEND_PORT.*,FRONTEND_PORT = 80,' \
  $RPM_BUILD_ROOT/srv/www/obs/webui/config/environments/development.rb
sed -i 's,api.opensuse.org,127.0.42.2,' \
  $RPM_BUILD_ROOT/srv/www/obs/webui/app/helpers/package_helper.rb

#
# Install webui theme
#
mkdir -p "$RPM_BUILD_ROOT/srv/www/obs/webui/public/themes/"
cp -av "$RPM_BUILD_DIR"/opensuse-themes/src/* "$RPM_BUILD_ROOT/srv/www/obs/webui/public/themes/"

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
#rm -f $RPM_BUILD_ROOT/srv/www/obs/api/lib/common $RPM_BUILD_ROOT/srv/www/obs/webui/lib/common
#ln -sf /srv/www/obs/common/lib $RPM_BUILD_ROOT/srv/www/obs/api/lib/common
#ln -sf /srv/www/obs/common/lib $RPM_BUILD_ROOT/srv/www/obs/webui/lib/common
#ln -sf /srv/www/obs/common/images $RPM_BUILD_ROOT/srv/www/obs/api/public/images/common
#ln -sf /srv/www/obs/common/images $RPM_BUILD_ROOT/srv/www/obs/webui/public/images/common
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
#for i in build events info jobs log projects repos run sources trees workers; do
#  install -d -m 755 $RPM_BUILD_ROOT/srv/obs/$i
#done
# install executables and code
cp -a * $RPM_BUILD_ROOT/usr/lib/obs/server/
rm -r   $RPM_BUILD_ROOT/usr/lib/obs/server/testdata
rm      $RPM_BUILD_ROOT/usr/lib/obs/server/Makefile.PL
cd ..

#
# turn duplicates into hard links
#
#%fdupes $RPM_BUILD_ROOT/srv/www/obs/api
#%fdupes $RPM_BUILD_ROOT/srv/www/obs/webui
# There's dupes between webui and api:
%if 0%{?suse_version} >= 1030
%fdupes $RPM_BUILD_ROOT/srv/www/obs
%endif

# these config files must not be hard linked
install api/config/database.yml.example $RPM_BUILD_ROOT/srv/www/obs/api/config/database.yml
install api/config/options.yml.example $RPM_BUILD_ROOT/srv/www/obs/api/config/options.yml
install webui/config/database.yml.example $RPM_BUILD_ROOT/srv/www/obs/webui/config/database.yml
install webui/config/options.yml.example $RPM_BUILD_ROOT/srv/www/obs/webui/config/options.yml

%pre
/usr/sbin/groupadd -r obsrun 2> /dev/null || :
/usr/sbin/useradd -r -o -s /bin/false -c "User for build service backend" -d /usr/lib/obs -g obsrun obsrun 2> /dev/null || :

%pre -n obs-worker
/usr/sbin/groupadd -r obsrun 2> /dev/null || :
/usr/sbin/useradd -r -o -s /bin/false -c "User for build service backend" -d /usr/lib/obs -g obsrun obsrun 2> /dev/null || :

%preun
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher obswarden obssigner ; do
%stop_on_removal $service
done

%preun -n obs-worker
%stop_on_removal obsworker

%post
[ -d /srv/obs ] || install -d -o obsrun -g obsrun /srv/obs
%run_permissions
%{fillup_and_insserv -n obs-server}
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher obswarden obssigner ; do
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
# cleanup empty directory just in case
rmdir /srv/obs 2> /dev/null || :

%post -n obs-worker
%{fillup_and_insserv -n obs-server}
# NOT used on purpose: restart_on_update obsworker
# This can cause problems when building chroot
# and bs_worker is anyway updating itself at runtime based on server code

%pre -n obs-api
# help rpm to turn a directory in a symlink
if [ -d /srv/www/obs/webui/public/vendor/neutral/images -a ! -L /srv/www/obs/webui/public/vendor/neutral/images ]; then
  mv /srv/www/obs/webui/public/vendor/neutral/images /srv/www/obs/webui/public/vendor/neutral/images.rpmold
fi

%post -n obs-api
%{fillup_and_insserv -n obs-server}
if [ -e /srv/www/obs/frontend/config/database.yml ] && [ ! -e /srv/www/obs/api/config/database.yml ]; then
  cp /srv/www/obs/frontend/config/database.yml /srv/www/obs/api/config/database.yml
fi
# updaters can keep their production_slave config
for i in production_slave.rb production.rb development_base.rb; do
  if [ -e /srv/www/obs/frontend/config/environments/$i ] && [ ! -e /srv/www/obs/api/config/environments/$i ]; then
    cp /srv/www/obs/frontend/config/environments/$i /srv/www/obs/api/config/environments/$i
  fi
done
# for update from 2.1(lighttpd), do a chown
if [ `stat -c %U /srv/www/obs/api/config/secret.key` == lighttpd ]; then
  chown wwwrun.www /srv/www/obs/api/config/secret.key
fi
if [ `stat -c %U /srv/www/obs/webui/config/secret.key` == lighttpd ]; then
  chown wwwrun.www /srv/www/obs/webui/config/secret.key
fi
echo '**** Keep in mind to run rake db:migrate after updating this package and restart apache (read README.UPDATERS) ****'

%postun -n obs-api
%insserv_cleanup

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc dist/{README.UPDATERS,README.SETUP} docs/openSUSE.org.xml ReleaseNotes-* README COPYING AUTHORS
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
/usr/lib/obs/server/BSSolv.pm
/usr/lib/obs/server/BSSolv.xs
/usr/lib/obs/server/typemap
/usr/lib/obs/server/worker-deltagen.spec
%config(noreplace) /usr/lib/obs/server/BSConfig.pm
%config(noreplace) /etc/slp.reg.d/*
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
/var/adm/fillup-templates/sysconfig.obs-server
/etc/init.d/obsworker
/etc/init.d/obsstoragesetup
/usr/sbin/rcobsworker
/usr/sbin/rcobsstoragesetup

%files -n obs-api
%defattr(-,root,root)
%doc dist/{README.UPDATERS,README.SETUP} docs/openSUSE.org.xml ReleaseNotes-* README COPYING AUTHORS
/srv/www/obs/overview

%dir /srv/www/obs
%dir /srv/www/obs/api
%dir /srv/www/obs/api/config
%dir /srv/www/obs/api/config/initializers
%dir /srv/www/obs/api/config/environments
%dir /srv/www/obs/api/files
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
/srv/www/obs/api/test
/srv/www/obs/api/vendor
/srv/www/obs/docs

#
# some files below config actually are _not_ config files
# so here we go, file by file
#

/srv/www/obs/api/config/boot.rb
/srv/www/obs/api/config/routes.rb
/srv/www/obs/api/config/environments/development.rb
%attr(0640,root,www) %config(noreplace) /srv/www/obs/api/config/database.yml*
%attr(0644,root,root) %config(noreplace) /srv/www/obs/api/config/options.yml*
/srv/www/obs/api/config/environments/production_test.rb
/srv/www/obs/api/config/initializers/options.rb
/srv/www/obs/api/config/initializers/logging.rb
/srv/www/obs/api/config/initializers/create_runtime_directories.rb

%config /srv/www/obs/api/config/environment.rb
%config(noreplace) /srv/www/obs/api/config/lighttpd.conf
%config(noreplace) /srv/www/obs/api/config/environments/production.rb
%config(noreplace) /srv/www/obs/api/config/environments/test.rb
%config(noreplace) /srv/www/obs/api/config/environments/stage.rb
%config(noreplace) /srv/www/obs/api/config/environments/development_base.rb
%config(noreplace) /srv/www/obs/api/config/active_rbac_config.rb
%config(noreplace) /srv/www/obs/api/files/distributions.xml
%config(noreplace) /etc/cron.d/obs-api

%dir %attr(-,wwwrun,www) /srv/www/obs/api/log
%verify(not size md5) %attr(-,wwwrun,www) /srv/www/obs/api/log/production.log
%attr(-,wwwrun,www) /srv/www/obs/api/tmp

# starting the webui part
%dir /srv/www/obs/webui
# sqlite3 needs write permissions
%dir %attr(-,wwwrun,www) /srv/www/obs/webui/db
/srv/www/obs/webui/app
/srv/www/obs/webui/db/migrate
/srv/www/obs/webui/db/schema.rb
/srv/www/obs/webui/lib
/srv/www/obs/webui/public
/srv/www/obs/webui/Rakefile
/srv/www/obs/webui/script
/srv/www/obs/webui/test
/srv/www/obs/webui/vendor

%dir /srv/www/obs/webui/config
%dir /srv/www/obs/webui/config/environments
%dir /srv/www/obs/webui/config/initializers
/srv/www/obs/webui/config/routes.rb
/srv/www/obs/webui/config/environments/development.rb
/srv/www/obs/webui/README.theme
/srv/www/obs/webui/config/initializers/options.rb
/srv/www/obs/webui/config/initializers/logging.rb
/srv/www/obs/webui/config/initializers/create_runtime_directories.rb
/srv/www/obs/webui/config/initializers/xhtml_init.rb

%config /srv/www/obs/webui/config/boot.rb
%config /srv/www/obs/webui/config/environment.rb
%config(noreplace) /srv/www/obs/webui/config/environments/production.rb
%config(noreplace) /srv/www/obs/webui/config/environments/test.rb
%config(noreplace) /srv/www/obs/webui/config/environments/stage.rb
%config(noreplace) /srv/www/obs/webui/config/environments/development_base.rb
%config(noreplace) /srv/www/obs/webui/config/initializers/theme_support.rb
%attr(0640,root,www) %config(noreplace) /srv/www/obs/webui/config/database.yml*
%attr(0644,root,root) %config(noreplace) /srv/www/obs/webui/config/options.yml*

%dir %attr(-,wwwrun,www) /srv/www/obs/webui/log
%config(noreplace) %verify(not size md5) %attr(-,wwwrun,www) /srv/www/obs/webui/db/database.db
%config(noreplace) %verify(not size md5) %attr(-,wwwrun,www) /srv/www/obs/webui/log/production.log
%attr(-,wwwrun,www) /srv/www/obs/webui/tmp

# these dirs primarily belong to apache2:
%dir /etc/apache2
%dir /etc/apache2/vhosts.d
%config(noreplace) /etc/apache2/vhosts.d/obs.conf

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

