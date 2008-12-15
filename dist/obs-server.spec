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

%define svnversion updated_by_script # edit VERSION in .distrc
Version:        %{svnversion}

Release:        0
License:        GPL
Group:          Productivity/Networking/Web/Utilities
Url:            http://en.opensuse.org/Build_Service
Source:         obs-server-%version.tar.bz2
Source1:        obsworker
Source3:        obspublisher
Source4:        obsrepserver
Source5:        obssrcserver
Source6:        obsscheduler
Source7:        obs.conf
Source8:        cleanurl-v5.lua
Source9:        rails.include
Source11:       sysconfig.obs-worker
Source12:       sysconfig.obs-server
Source13:       obs_mirror_project
Source16:       obs_project_update
Source15:       obsdispatcher
Source20:       obssignd
Autoreqprov:    on
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  python-devel rubygem-activesupport

%if 0%{?suse_version} >= 1030
BuildRequires:  fdupes
%endif

%if 0%{?suse_version:1}
PreReq:         %fillup_prereq %insserv_prereq permissions
%endif

%if 0%{?suse_version} >= 1020
Recommends:     yum yum-metadata-parser repoview dpkg
Recommends:     createrepo >= 0.4.10
%else
Requires:       yum yum-metadata-parser repoview dpkg
Requires:       createrepo >= 0.4.10
%endif
Requires:       createrepo
Requires:       perl-Compress-Zlib perl-Net_SSLeay perl-Socket-MsgHdr perl-XML-Parser

#-------------------------------------------------------------------------------
%description
#-------------------------------------------------------------------------------
Authors:
--------
    The openSUSE Team <opensuse-buildservice@opensuse.org>

--------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
%package -n obs-worker
#-------------------------------------------------------------------------------

Requires:	perl-TimeDate screen curl perl-XML-Parser perl-Compress-Zlib

Summary:        The openSUSE Build Service -- Build Host Component
Group:          Productivity/Networking/Web/Utilities

%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif
%if 0%{?suse_version} <= 1030
Requires:       lzma
%endif
%ifarch x86_64
Requires:	linux32
%endif

%ifarch ppc64
Requires:	powerpc32
%endif

#-------------------------------------------------------------------------------
%description -n obs-worker
#-------------------------------------------------------------------------------
This is the obs build host, to be installed on each machine building
packages in this obs installation.  Install it alongside obs-server to
run a local playground test installation.
#-------------------------------------------------------------------------------
%package -n obs-api
#-------------------------------------------------------------------------------
Summary:        The openSUSE Build Service -- The Frontend part
Group:          Productivity/Networking/Web/Utilities

%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif

Requires:       lighttpd ruby-fcgi lighttpd-mod_magnet mysql ruby-mysql rubygem-rake
Requires:       rubygem-rails >= 2.0
Group:          Productivity/Networking/Web/Utilities
Summary:        The openSUSE Build Service -- The Frontend part

#-------------------------------------------------------------------------------
%description -n obs-api
#-------------------------------------------------------------------------------
This is the obs web API (rest) frontend, and the web client to the
obs.  See osc for a command line client.  Install obs-api alongside
obs-server to run a local playground test installation.
#-------------------------------------------------------------------------------
%package -n obs-signd
#-------------------------------------------------------------------------------
Summary:        The openSUSE Build Service -- gpg sign daemon
Group:          Productivity/Networking/Web/Utilities

BuildRequires:  gcc
Requires:       gnupg

#-------------------------------------------------------------------------------
%description -n obs-signd
#-------------------------------------------------------------------------------
signd is a little daemon that listens for sign requests from sign,
and either calls gpg to do the signing or forwards the request
to another signd. The -f option makes signd fork on startup.

signd uses the same configuration used for sign, /etc/sign.conf.
It needs a gpg implementation that understands the
"--files-are-digests" option to work correctly.

  Author:	Michael Schroeder

--------------------------------------------------------------------------------
%package -n obs-productconverter
#-------------------------------------------------------------------------------
Summary:        The openSUSE Build Service -- product definition utility
Group:          Productivity/Networking/Web/Utilities
# For perl library files, TODO: split out obs-lib subpackage?
Requires:       obs-server
#-------------------------------------------------------------------------------
%description -n obs-productconverter
#-------------------------------------------------------------------------------
bs_productconvert is a utility to create Kiwi- and Spec- files from a
product definition.
#-------------------------------------------------------------------------------
%package -n obs-utils
#-------------------------------------------------------------------------------
Summary:        The openSUSE Build Service -- utilities
Group:          Productivity/Networking/Web/Utilities
Requires:       osc build ruby 
#-------------------------------------------------------------------------------
%description -n obs-utils
#-------------------------------------------------------------------------------
obs_mirror_project is a tool to copy the binary data of a project from one obs to another
obs_project_update is a tool to copy a packages of a project from one obs to another

Authors:       Susanne Oberhauser, Martin Mohring

#--------------------------------------------------------------------------------
%prep
%setup -q -n buildservice/1.5

#-------------------------------------------------------------------------------
%build
#-------------------------------------------------------------------------------
#
# generate apidocs
#
cd docs/api/frontend
make apidocs
cd -
#
# make sign binary
#
cd src/sign
gcc $RPM_OPT_FLAGS -o sign sign.c
cd -

#-------------------------------------------------------------------------------
%install
#-------------------------------------------------------------------------------
#
# Install all web and frontend parts.
#
cd src
for i in common frontend webclient; do
  mkdir -p $RPM_BUILD_ROOT/srv/www/obs/
  cp -a $i $RPM_BUILD_ROOT/srv/www/obs/$i
done
# configure lighttpd web service
mkdir -p $RPM_BUILD_ROOT/etc/lighttpd/vhosts.d/
install -m 0644 %SOURCE7 $RPM_BUILD_ROOT/etc/lighttpd/vhosts.d/
install -m 0644 %SOURCE9 $RPM_BUILD_ROOT/etc/lighttpd/vhosts.d/rails.inc
install -m 0644 %SOURCE8 $RPM_BUILD_ROOT/etc/lighttpd/
rm $RPM_BUILD_ROOT/srv/www/obs/frontend/README_LOGIN
rm $RPM_BUILD_ROOT/srv/www/obs/frontend/files/specfiletemplate
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/frontend/log
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/webclient/log
touch $RPM_BUILD_ROOT/srv/www/obs/{webclient,frontend}/log/development.log

# fix path
for i in $RPM_BUILD_ROOT/srv/www/obs/*/config/environment.rb; do
  sed "s,/srv/www/opensuse/common/current/lib,/srv/www/obs/common/lib," \
    "$i" > "$i"_ && mv "$i"_ "$i"
done
#
#set default api on localhost for the webclient
# 
sed 's,FRONTEND_HOST.*,FRONTEND_HOST = "127.0.42.2",' \
  $RPM_BUILD_ROOT/srv/www/obs/webclient/config/environments/development.rb > tmp-file \
  && mv tmp-file "$RPM_BUILD_ROOT/srv/www/obs/webclient/config/environments/development.rb"
sed 's,FRONTEND_PORT.*,FRONTEND_PORT = 80,' \
  $RPM_BUILD_ROOT/srv/www/obs/webclient/config/environments/development.rb > tmp-file \
  && mv tmp-file "$RPM_BUILD_ROOT/srv/www/obs/webclient/config/environments/development.rb"
sed 's,api.opensuse.org,127.0.42.2,' \
  $RPM_BUILD_ROOT/srv/www/obs/webclient/app/helpers/package_helper.rb > tmp-file \
  && mv tmp-file "$RPM_BUILD_ROOT/srv/www/obs/webclient/app/helpers/package_helper.rb"

#
# install apidocs
# 
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/frontend/public/apidocs/html/
cp -a ../docs/api/html           $RPM_BUILD_ROOT/srv/www/obs/frontend/public/apidocs/
mkdir -p $RPM_BUILD_ROOT/srv/www/obs/frontend/public/schema/
cp -a ../docs/api/frontend/*.{rng,xsd}    $RPM_BUILD_ROOT/srv/www/obs/frontend/public/schema/
#
# Install all backend parts.
#
cd backend/
mv BSConfig.pm.template BSConfig.pm

install -d -m 755 $RPM_BUILD_ROOT/usr/lib/obs/server/
install -d -m 755 $RPM_BUILD_ROOT/usr/sbin/
install -d -m 755 $RPM_BUILD_ROOT/etc/init.d/
install -d -m 755 $RPM_BUILD_ROOT/srv/obs/projects
install -d -m 755 $RPM_BUILD_ROOT/srv/obs/log
install -d -m 755 $RPM_BUILD_ROOT/srv/obs/run
# install executables and code
cp -a * $RPM_BUILD_ROOT/usr/lib/obs/server/
rm -rf  $RPM_BUILD_ROOT/usr/lib/obs/server/testdata
# install obs mirror script and obs copy script
install -m 0755 %SOURCE13 %SOURCE16 $RPM_BUILD_ROOT/usr/sbin/
# install  runlevel scripts
install -m 0755 %SOURCE1 %SOURCE3 %SOURCE4 %SOURCE5 %SOURCE6 %SOURCE15 \
           $RPM_BUILD_ROOT/etc/init.d/
for i in obssrcserver obsrepserver obsscheduler obsworker obspublisher obsdispatcher ; do
  ln -sf /etc/init.d/$i $RPM_BUILD_ROOT/usr/sbin/rc$i
done
# Ship latest version of build to be always in sync. do not use the symlink.
rm -rf $RPM_BUILD_ROOT/usr/lib/obs/server/build
cp -a ../build $RPM_BUILD_ROOT/usr/lib/obs/server/build
# install fillups
FILLUP_DIR=$RPM_BUILD_ROOT/var/adm/fillup-templates
mkdir -p $FILLUP_DIR
cp -a %SOURCE11 %SOURCE12 $FILLUP_DIR/

#
# turn duplicates into hard links
#
#%fdupes $RPM_BUILD_ROOT/srv/www/obs/frontend
#%fdupes $RPM_BUILD_ROOT/srv/www/obs/webclient
# There's dupes between webclient and frontend:
%if 0%{?suse_version} >= 1030
%fdupes $RPM_BUILD_ROOT/srv/www/obs
%endif
#
# Install sign stuff
#
cd ../sign/
install -d -m 0755 $RPM_BUILD_ROOT%{_mandir}/man{5,8}
install -d -m 0755 $RPM_BUILD_ROOT/usr/bin
install -m 0755 signd $RPM_BUILD_ROOT/usr/sbin/
install -m 0750 sign $RPM_BUILD_ROOT/usr/bin/
install -m 0644 sign.conf $RPM_BUILD_ROOT/etc/
install -m 0755 %SOURCE20 $RPM_BUILD_ROOT/etc/init.d/obssignd
ln -sf /etc/init.d/obssignd $RPM_BUILD_ROOT/usr/sbin/rcobssignd
for j in `ls sig*.{5,8}`; do
  gzip -9 ${j}
done
for k in 5 8; do
  install -m 0644 sig*.${k}.gz $RPM_BUILD_ROOT%{_mandir}/man${k}/
done

#-------------------------------------------------------------------------------
%pre
#-------------------------------------------------------------------------------
/usr/sbin/groupadd -r obsrun 2> /dev/null || :
/usr/sbin/useradd -r -o -s /bin/false -c "User for build service backend" -d /usr/lib/obs -g obsrun obsrun 2> /dev/null || :

#-------------------------------------------------------------------------------
%preun
#-------------------------------------------------------------------------------
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher; do
%stop_on_removal $service
done

#-------------------------------------------------------------------------------
%post -n obs-server
#-------------------------------------------------------------------------------
%run_permissions
%{fillup_and_insserv -n obs-server}
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher; do
%restart_on_update $service
done
#-------------------------------------------------------------------------------
%postun -n obs-server
#-------------------------------------------------------------------------------
%insserv_cleanup
#-------------------------------------------------------------------------------
%verifyscript -n obs-server
#-------------------------------------------------------------------------------
%verify_permissions -e /usr/bin/sign

#-------------------------------------------------------------------------------
%post -n obs-worker
#-------------------------------------------------------------------------------
%{fillup_and_insserv -n obs-worker}
%restart_on_update obsworker

#-------------------------------------------------------------------------------
%post -n obs-api
#-------------------------------------------------------------------------------
%restart_on_update lighttpd

#-------------------------------------------------------------------------------
%postun -n obs-signd
#-------------------------------------------------------------------------------
%insserv_cleanup

#-------------------------------------------------------------------------------
%postun -n obs-api
#-------------------------------------------------------------------------------
%insserv_cleanup

#-------------------------------------------------------------------------------
%clean
#-------------------------------------------------------------------------------
[ "$RPM_BUILD_ROOT" != "/" ] && [ -d $RPM_BUILD_ROOT ] && %{__rm} -rf $RPM_BUILD_ROOT

#-------------------------------------------------------------------------------
%files
#-------------------------------------------------------------------------------
%defattr(-,root,root)
%dir /usr/lib/obs
%dir /usr/lib/obs/server
/etc/init.d/obsdispatcher
/etc/init.d/obspublisher
/etc/init.d/obsrepserver
/etc/init.d/obsscheduler
/etc/init.d/obssrcserver
/usr/sbin/rcobsdispatcher
/usr/sbin/rcobspublisher
/usr/sbin/rcobsrepserver
/usr/sbin/rcobsscheduler
/usr/sbin/rcobssrcserver
/usr/lib/obs/server/BSBuild.pm
/usr/lib/obs/server/BSConfig.pm
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
/usr/lib/obs/server/COPYING
/usr/lib/obs/server/DESIGN
/usr/lib/obs/server/License
/usr/lib/obs/server/README
/usr/lib/obs/server/TODO
/usr/lib/obs/server/XML
/usr/lib/obs/server/bs_*
/usr/lib/obs/server/build
/usr/lib/obs/server/worker
/usr/lib/obs/server/BSHermes.pm
%attr(-,obsrun,obsrun) /srv/obs
/var/adm/fillup-templates/sysconfig.obs-server
%{_mandir}/man5/*
# the sign client goes with the server
%verify(not mode) %attr(0750,root,obsrun) /usr/bin/sign
%{_mandir}/man8/sign.8.gz

#-------------------------------------------------------------------------------
%files -n obs-worker
#-------------------------------------------------------------------------------
%defattr(-,root,root)
/var/adm/fillup-templates/sysconfig.obs-worker
/etc/init.d/obsworker
/usr/sbin/rcobsworker

#-------------------------------------------------------------------------------
%files -n obs-api
#-------------------------------------------------------------------------------
%defattr(-,root,root)
%doc dist/{TODO,README.UPDATERS,README.SETUP} docs/openSUSE.org.xml ReleaseNotes-* README COPYING
%dir /srv/www/obs
/srv/www/obs/common
%dir /srv/www/obs/frontend
/srv/www/obs/frontend/app
/srv/www/obs/frontend/Changelog
/srv/www/obs/frontend/components
/srv/www/obs/frontend/db
/srv/www/obs/frontend/doc
/srv/www/obs/frontend/files
/srv/www/obs/frontend/lib
/srv/www/obs/frontend/public
/srv/www/obs/frontend/Rakefile
/srv/www/obs/frontend/README
/srv/www/obs/frontend/script
/srv/www/obs/frontend/test
/srv/www/obs/frontend/vendor
%dir /srv/www/obs/webclient
/srv/www/obs/webclient/app
/srv/www/obs/webclient/Changelog
/srv/www/obs/webclient/components
/srv/www/obs/webclient/db
/srv/www/obs/webclient/doc
/srv/www/obs/webclient/lib
/srv/www/obs/webclient/public
/srv/www/obs/webclient/Rakefile
/srv/www/obs/webclient/README
/srv/www/obs/webclient/script
/srv/www/obs/webclient/test
/srv/www/obs/webclient/vendor
#
# some files below config actually are _not_ config files
# so here we go, file by file
#

/srv/www/obs/frontend/config/boot.rb
/srv/www/obs/frontend/config/routes.rb
/srv/www/obs/frontend/config/environments/development.rb

%dir /srv/www/obs/frontend/config
%dir /srv/www/obs/frontend/config/environments

%config(noreplace) /srv/www/obs/frontend/config/database.yml
%config(noreplace) /srv/www/obs/frontend/config/environment.rb
%config(noreplace) /srv/www/obs/frontend/config/deploy.rb.template
%config(noreplace) /srv/www/obs/frontend/config/lighttpd.conf
%config(noreplace) /srv/www/obs/frontend/config/environments/production_slave.rb
%config(noreplace) /srv/www/obs/frontend/config/environments/development.L12.rb
%config(noreplace) /srv/www/obs/frontend/config/environments/production.rb
%config(noreplace) /srv/www/obs/frontend/config/environments/test.rb
%config(noreplace) /srv/www/obs/frontend/config/environments/stage.rb
%config(noreplace) /srv/www/obs/frontend/config/environments/development_base.rb
%config(noreplace) /srv/www/obs/frontend/config/active_rbac_config.rb

%dir /srv/www/obs/webclient/config
%dir /srv/www/obs/webclient/config/environments

/srv/www/obs/webclient/config/routes.rb
/srv/www/obs/webclient/config/environments/development.rb

%config(noreplace) /srv/www/obs/webclient/config/database.yml
%config(noreplace) /srv/www/obs/webclient/config/boot.rb
%config(noreplace) /srv/www/obs/webclient/config/environment.rb
%config(noreplace) /srv/www/obs/webclient/config/deploy.rb.template
%config(noreplace) /srv/www/obs/webclient/config/environments/production_slave.rb
%config(noreplace) /srv/www/obs/webclient/config/environments/production.rb
%config(noreplace) /srv/www/obs/webclient/config/environments/test.rb
%config(noreplace) /srv/www/obs/webclient/config/environments/stage.rb
%config(noreplace) /srv/www/obs/webclient/config/environments/development_base.rb

%dir %attr(-,lighttpd,lighttpd) /srv/www/obs/frontend/log
%dir %attr(-,lighttpd,lighttpd) /srv/www/obs/webclient/log
%verify(not size md5) %attr(-,lighttpd,lighttpd) /srv/www/obs/frontend/log/development.log
%verify(not size md5) %attr(-,lighttpd,lighttpd) /srv/www/obs/webclient/log/development.log
%attr(-,lighttpd,lighttpd) /srv/www/obs/frontend/tmp
%attr(-,lighttpd,lighttpd) /srv/www/obs/webclient/tmp
%config(noreplace) /etc/lighttpd/vhosts.d/obs.conf
# these dirs primarily belong to lighttpd:
%dir /etc/lighttpd
%dir /etc/lighttpd/vhosts.d
%config /etc/lighttpd/cleanurl-v5.lua
%config /etc/lighttpd/vhosts.d/rails.inc

#-------------------------------------------------------------------------------
%files -n obs-signd
#-------------------------------------------------------------------------------
%defattr(-,root,root)
%config(noreplace) /etc/sign.conf
/usr/sbin/signd
/usr/sbin/rcobssignd
/etc/init.d/obssignd
%{_mandir}/man5/*
%{_mandir}/man8/signd.8.gz

#-------------------------------------------------------------------------------
%files -n obs-utils
#-------------------------------------------------------------------------------
%defattr(-,root,root)
/usr/sbin/obs_mirror_project
/usr/sbin/obs_project_update

#-------------------------------------------------------------------------------
%files -n obs-productconverter
#-------------------------------------------------------------------------------
%defattr(-,root,root)
/usr/lib/obs/server/bs_productconvert

#-------------------------------------------------------------------------------
%changelog -n obs-server
