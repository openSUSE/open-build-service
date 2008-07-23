#
# spec file for package obs-server (Version 0.9.99)
#
# Copyright (c) 2008 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#



Name:           obs-server
Requires:       perl-Socket-MsgHdr perl-XML-Parser perl-Compress-Zlib createrepo perl-Net_SSLeay
BuildRequires:  python-devel rubygem-builder
%if 0%{?suse_version:1}
PreReq:         %fillup_prereq %insserv_prereq
%endif
License:        GPL
Group:          Productivity/Networking/Web/Utilities
AutoReqProv:    on
Version:        1.0.99
Release:        0
Url:            http://en.opensuse.org/Build_Service
Summary:        The openSUSE Build Service -- Server Component
Source:         buildservice-%version.tar.bz2
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
Source15:       obsdispatcher
Source20:       obssignd
%if 0%{?suse_version} >= 1020
Recommends:     yum yum-metadata-parser repoview dpkg
Recommends:     createrepo >= 0.4.10
%else
Requires:       yum yum-metadata-parser repoview dpkg
Requires:       createrepo >= 0.4.10
%endif
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch

%description
Authors:
--------
    The openSUSE Team <opensuse-buildservice@opensuse.org>

%package -n obs-worker

Requires:       perl-TimeDate screen curl perl-XML-Parser perl-Compress-Zlib
%ifarch x86_64
Requires:       linux32
%endif
%ifarch ppc64
Requires:       powerpc32
%endif
%if 0%{?suse_version} <= 1030
Requires:       lzma
%endif
%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif
Group:          Productivity/Networking/Web/Utilities
Summary:        The openSUSE Build Service -- Build Host Component

%description -n obs-worker

%package -n obs-api

%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif
Requires:       lighttpd ruby-fcgi lighttpd-mod_magnet mysql ruby-mysql rubygem-rake
Requires:       rubygem-rails >= 2.0
Group:          Productivity/Networking/Web/Utilities
Summary:        The openSUSE Build Service -- The Frontend part

%description -n obs-api

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

Author:       Michael Schroeder

%prep
%setup -q -n buildservice-%version

%build
#
# generate apidocs
#
cd docs/api/frontend
make apidocs
cd -
#
# compile signd
#
cd src/sign
gcc -o sign sign.c
cd -

%install
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
install -d -m 755 $RPM_BUILD_ROOT/usr/lib/obs/server/
install -d -m 755 $RPM_BUILD_ROOT/usr/sbin/
install -d -m 755 $RPM_BUILD_ROOT/etc/init.d/
install -d -m 755 $RPM_BUILD_ROOT/srv/obs/projects
install -d -m 755 $RPM_BUILD_ROOT/srv/obs/log
install -d -m 755 $RPM_BUILD_ROOT/srv/obs/run
# install executables and code
cp -a * $RPM_BUILD_ROOT/usr/lib/obs/server/
# install mirror script
install -m 0755 %SOURCE13 $RPM_BUILD_ROOT/usr/sbin/
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

%pre
/usr/sbin/groupadd -r obsrun 2> /dev/null || :
/usr/sbin/useradd -r -o -s /bin/false -c "User for build service backend" -d /usr/lib/obs -g obsrun obsrun 2> /dev/null || :

%preun
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher; do
%stop_on_removal $service
done

%post -n obs-server
%{fillup_and_insserv -n obs-server}
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher; do
%restart_on_update $service
done

%post -n obs-worker
%{fillup_and_insserv -n obs-worker}
%restart_on_update obsworker

%post -n obs-api
touch /srv/www/obs/{webclient,frontend}/log/development.log
chown lighttpd:lighttpd /srv/www/obs/{webclient,frontend}/log/development.log
%restart_on_update lighttpd

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%dir /usr/lib/obs
%dir /usr/lib/obs/server
/etc/init.d/obsdispatcher
/etc/init.d/obspublisher
/etc/init.d/obsrepserver
/etc/init.d/obsscheduler
/etc/init.d/obssrcserver
%attr(4750,root,obsrun) /usr/bin/sign
/usr/sbin/rcobsdispatcher
/usr/sbin/rcobspublisher
/usr/sbin/rcobsrepserver
/usr/sbin/rcobsscheduler
/usr/sbin/rcobssrcserver
/usr/sbin/obs_mirror_project
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

%files -n obs-worker
%defattr(-,root,root)
/var/adm/fillup-templates/sysconfig.obs-worker
/etc/init.d/obsworker
/usr/sbin/rcobsworker

%files -n obs-api
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
%config(noreplace) /srv/www/obs/frontend/config
%config(noreplace) /srv/www/obs/webclient/config
%attr(-,lighttpd,lighttpd) /srv/www/obs/frontend/log
%attr(-,lighttpd,lighttpd) /srv/www/obs/frontend/tmp
%attr(-,lighttpd,lighttpd) /srv/www/obs/webclient/log
%attr(-,lighttpd,lighttpd) /srv/www/obs/webclient/tmp
%config(noreplace) /etc/lighttpd/vhosts.d/obs.conf
%config /etc/lighttpd/cleanurl-v5.lua
%config /etc/lighttpd/vhosts.d/rails.inc

%files -n obs-signd
%defattr(-,root,root)
%config(noreplace) /etc/sign.conf
/usr/sbin/signd
/usr/sbin/rcobssignd
/etc/init.d/obssignd
%{_mandir}/man5/*
%{_mandir}/man8/sign*

%changelog
* Wed Jul 09 2008 - chris@computersalat.de
- added sign/signd stuff
* Wed Jun 18 2008 dmueller@suse.de
- also restart dispatcher on update
* Wed Jun 11 2008 martin.mohring@5etech.eu
- update to svn trunc -r 4169
- heading toward OBS 1.0
- fixed requires again
- dont copy doc files, they are packaged already in .tar.bz2
- put all docu files in obs-api package
- some %%pre / %%post alignments
- schemata and doc now mentioned in config
* Tue Jun 03 2008 martin.mohring@5etech.eu
- update to svn trunc -r 4091
- incl. bugfixes, see svn log
- added hermes
* Mon Jun 02 2008 martin.mohring@5etech.eu
- update to svn trunc -r 4074, bugfixes
- added file of the spec file wizard now added
- new debtransform features
- build now has opensuse 11.0 config
- osc develproj and branch support
* Sat May 24 2008 martin.mohring@5etech.eu
- update to svn trunc -r 4026, bugfixes
- exchanged dpkg package by deb package, provided by newer openSUSE Distros
* Mon May 19 2008 martin.mohring@5etech.eu
- update to svn trunc -r 3996, bugfixes
- incl. latest osc alignments for 1.0 release
- added obs-server-test.spec for building osc, build, obs-server from one source
* Fri May 16 2008 martin.mohring@5etech.eu
- update to svn trunc -r 3983, incl. all build/obs_worker changes
- readded fix for changing download addresses in webclient
* Thu May 15 2008 martin.mohring@5etech.eu
- added also old python written script obs_mirror_project.py from James Oakley
* Thu May 15 2008 martin.mohring@5etech.eu
- made apidocs working (finally)
- got back to old svn version numbering so that ./distribute generates all
- updated to newer versions of rcobs scripts
- switchable comment for x86_64 scheduler in sysconfig.obs-server
- removed obsoleted files from svn and .spec file
- updates of obs-server.changes from openSUSE:Tools:Unstable project
* Wed May 14 2008 adrian@suse.de
- update to current svn trunk
- avoid more hardcoded server names
- bsworker can be installed on remote systems now and configured
  via sysconfig settings
- add apidocs generation and correct installation
* Fri Apr 25 2008 adrian@suse.de
- update to version 0.9.1
  - fixes from the changelog entries before
- Version 0.9.1 is required now to use the build service
  inter connect feature with api.opensuse.org
* Wed Apr 23 2008 mls@suse.de
- increase timeouts in scheduler
- fix circular reference in BSSSL
- fix auto socket close in BSRPC
* Thu Apr 17 2008 adrian@suse.de
- apply fix for
  * local osc support building for remote projects
  * fix ssl protocol handling
* Thu Apr 17 2008 mrueckert@suse.de
- added perl-Net_SSLeay
* Wed Apr 16 2008 adrian@suse.de
- update to version 0.9 release
  * Inter Build Service Connect support
  * rpmlint support
  * KIWI imaging support
  * baselibs build support
  * submission request support
* Mon Nov 26 2007 froh@suse.de
- use startproc
- have correct "Should-Start" dependencies
- ensure all services come up at boot
* Thu Nov 15 2007 froh@suse.de
- depend on exact rails version
- generate package from buildservice/dist dir
- update README.SETUP
- add publisher and dispatcher
* Fri Jan 26 2007 poeml@suse.de
- implement status/restart in the init scripts
* Fri Jan 26 2007 poeml@suse.de
- added dependency on createrepo
* Fri Jan 26 2007 poeml@suse.de
- update to r1110
  - revert last change, and do it the ruby way, by creating a new
  migration for it... so existing installations are upgraded
  - fix truncated line in sorting algorithm
  - add missing mkdir
  - add url to package metadata
- fix build / install sysconfig files
- fix copyright headers in init script
- fix path in README where to copy packages to
* Thu Jan 25 2007 poeml@suse.de
- update to r1108
  create a few more architectures, when initializing the database
