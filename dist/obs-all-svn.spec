#
# spec file for package obs-server
#
# Copyright (c) 2008 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:           obs-server-svn
Conflicts:      obs-server
Requires:       perl-Socket-MsgHdr perl-XML-Parser perl-Compress-Zlib createrepo perl-Net_SSLeay
BuildRequires:  python-devel rubygem-activesupport
%if 0%{?suse_version:1}
PreReq:         %fillup_prereq %insserv_prereq
%endif
License:        GPL
Group:          Productivity/Networking/Web/Utilities
AutoReqProv:    on
%define svnversion updated_by_script # edit VERSION in .distrc
Version:        %{svnversion}
Release:        0
Url:            http://en.opensuse.org/Build_Service
Summary:        The openSUSE Build Service -- Server Component
Source:         obs-all-%{svnversion}.tar.bz2
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
Source14:       obs_mirror_project.py
Source16:       obs_project_update
Source17:       obs_project_srcimport
Source15:       obsdispatcher
Source20:       obssignd
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
%if 0%{?suse_version} >= 1030
Requires:       yum yum-metadata-parser repoview
Requires:       dpkg >= 1.15
Requires:       createrepo >= 0.4.10
Requires:       perl-BSSolv
BuildRequires:  build
BuildRequires:  -post-build-checks
BuildRequires:  perl-BSSolv
Recommends:     openslp-server
%else
Requires:       yum yum-metadata-parser repoview dpkg
Requires:       createrepo >= 0.4.10
%endif

%description
Authors:
--------
    The openSUSE Team <opensuse-buildservice@opensuse.org>


%package -n osc-obs
Summary:        The openSUSE Build Service -- Build Service Commander
Group:          Development/Tools/Other
License:        GNU General Public License (GPL)
Requires:       python-urlgrabber
Requires:       build-obs
Conflicts:      osc

%if 0%{?suse_version}
%if %suse_version < 1020
BuildRequires:  python-elementtree
Requires:       python-elementtree
%else
BuildRequires:  python-xml
Requires:       python-xml
%endif
%if %suse_version > 1000
Recommends:     rpm-python
%endif
%endif
%if 0%{?rhel_version} || 0%{?centos_version}
BuildRequires:  python-elementtree
Requires:       python-elementtree
%endif

%define python_sitelib %(python -c "from distutils.sysconfig import get_python_lib; print get_python_lib()")

%description -n osc-obs
Commandline client for the openSUSE build service.

See http://en.opensuse.org/Build_Service/CLI , as well as
http://en.opensuse.org/Build_Service_Tutorial for a general introduction.

Authors:
--------
    Peter Poeml <poeml@suse.de>

%package -n build-obs

Requires:       lzma
Conflicts:      build
%ifarch x86_64
Requires:       linux32
%endif
%ifarch ppc64
Requires:       powerpc32
%endif
%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif
Group:          Development/Tools/Building
Summary:        A Script to Build SUSE Linux RPMs and Debian DEBs

%description -n build-obs
This package provides a script for building RPMs for SUSE Linux in a
chroot environment.

%package -n obs-worker-svn

Requires:       perl-TimeDate screen curl perl-XML-Parser perl-Compress-Zlib
Requires:       lzma
Conflicts:      obs-worker
%ifarch x86_64
Requires:       linux32
%endif
%ifarch ppc64
Requires:       powerpc32
%endif
%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif
Group:          Productivity/Networking/Web/Utilities
Summary:        The openSUSE Build Service -- Build Host Component

%description -n obs-worker-svn

%package -n obs-api-svn

%if 0%{?suse_version}
PreReq:         %fillup_prereq %insserv_prereq
%endif
BuildRequires:  lighttpd
Requires:       lighttpd ruby-fcgi lighttpd-mod_magnet mysql ruby-mysql rubygem-rake
Requires:       rubygem-rails >= 2.0
Conflicts:      obs-api
Group:          Productivity/Networking/Web/Utilities
Summary:        The openSUSE Build Service -- The Frontend part

%description -n obs-api-svn

#-------------------------------------------------------------------------------
%package -n obs-signd-svn
#-------------------------------------------------------------------------------
Summary:        The openSUSE Build Service -- gpg sign daemon
Group:          Productivity/Networking/Web/Utilities

BuildRequires:  gcc
Requires:       gnupg
Conflicts:      obs-signd

#-------------------------------------------------------------------------------
%description -n obs-signd-svn
#-------------------------------------------------------------------------------
signd is a little daemon that listens for sign requests from sign,
and either calls gpg to do the signing or forwards the request
to another signd. The -f option makes signd fork on startup.

signd uses the same configuration used for sign, /etc/sign.conf.
It needs a gpg implementation that understands the
"--files-are-digests" option to work correctly.

Author:       Michael Schroeder
#-------------------------------------------------------------------------------
%package -n obs-productconverter-svn
#-------------------------------------------------------------------------------
Summary:        The openSUSE Build Service -- Product Definition Utility
Group:          Productivity/Networking/Web/Utilities
Requires:       obs-server-svn
Conflicts:      obs-productconverter
#-------------------------------------------------------------------------------
%description -n obs-productconverter-svn
#-------------------------------------------------------------------------------
bs_productconvert is a utility to create Kiwi- and Spec- files from a
product definition.
#-------------------------------------------------------------------------------
%package -n obs-utils-svn
#-------------------------------------------------------------------------------
Summary:        The openSUSE Build Service -- Utilities
Group:          Productivity/Networking/Web/Utilities

Requires:       osc-obs build-obs ruby 
Conflicts:      obs-utils

#-------------------------------------------------------------------------------
%description -n obs-utils-svn
#-------------------------------------------------------------------------------
obs_mirror_project is a tool to copy the binary data of a project from one obs to another
obs_project_update is a tool to copy a packages of a project from one obs to another

Authors:       Susanne Froh, Martin Mohring

#-------------------------------------------------------------------------------
%package -n obs-sourceservice-svn
#-------------------------------------------------------------------------------
Summary:        The openSUSE Build Service -- gpg sign daemon
Group:          Productivity/Networking/Web/Utilities

Conflicts:      obs-source_service

#-------------------------------------------------------------------------------
%description -n obs-sourceservice-svn
#-------------------------------------------------------------------------------
The OBS source service is a component to modify submitted sources
on the server side. This may include source checkout, spec file
generation, gpg validation, quality checks and other stuff.

This component is optional and not required to run the service.

Authors:       Adrian Schroeter, Michael Schroeder

%prep
%setup -q -n buildservice

%build
# generate apidocs
cd docs/api/frontend
make apidocs
cd -

# compile sign
cd src/sign
gcc -o sign sign.c
cd -

# compile osc python files
cd src/clientlib/python/osc
CFLAGS="%{optflags}" %{__python} setup.py build
cd -

%install
#
# Install all osc files
#
cd src/clientlib/python/osc
%{__python} setup.py install --prefix=%{_prefix} --root %{buildroot}
ln -s osc-wrapper.py %{buildroot}/%{_bindir}/osc
mkdir -p %{buildroot}/var/lib/osc-plugins
mkdir -p %{buildroot}%{_sysconfdir}/profile.d
install -m 0755 dist/complete.csh %{buildroot}%{_sysconfdir}/profile.d/osc.csh
install -m 0755 dist/complete.sh %{buildroot}%{_sysconfdir}/profile.d/osc.sh
%if 0%{?suse_version} > 1110
mkdir -p %{buildroot}%{_prefix}/lib/osc
install -m 0755 dist/osc.complete %{buildroot}%{_prefix}/lib/osc/complete
%else
mkdir -p %{buildroot}%{_prefix}/%{_lib}/osc
install -m 0755 dist/osc.complete %{buildroot}%{_prefix}/%{_lib}/osc/complete
%endif
cd -



#
# Install all build files
#
cd src/build
make DESTDIR=$RPM_BUILD_ROOT install
cd -
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
#set default api on localhost for the webclient
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
rm      $RPM_BUILD_ROOT/usr/lib/obs/server/Makefile.PL

# install obs mirror script and obs copy script
install -m 0755 %SOURCE13 %SOURCE14 %SOURCE16 %SOURCE17 $RPM_BUILD_ROOT/usr/sbin/
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
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher ; do
%stop_on_removal $service
done

%post -n obs-server-svn
%{fillup_and_insserv -n obs-server}
for service in obssrcserver obsrepserver obsdispatcher obsscheduler obspublisher ; do
%restart_on_update $service
done

%post -n obs-worker-svn
%{fillup_and_insserv -n obs-worker}
%restart_on_update obsworker

%post -n obs-api-svn
%restart_on_update lighttpd

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/etc/init.d/obsdispatcher
/etc/init.d/obspublisher
/etc/init.d/obsrepserver
/etc/init.d/obsscheduler
/etc/init.d/obssrcserver
%if 0%{?suse_version} >= 1110
#with openSUSE 11.1 sbit progs have to registered
/usr/bin/sign
%else
%attr(4750,root,obsrun) /usr/bin/sign
%endif
/usr/sbin/rcobsdispatcher
/usr/sbin/rcobspublisher
/usr/sbin/rcobsrepserver
/usr/sbin/rcobsscheduler
/usr/sbin/rcobssrcserver
%dir /usr/lib/obs
%dir /usr/lib/obs/server
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
/usr/lib/obs/server/COPYING
/usr/lib/obs/server/DESIGN
/usr/lib/obs/server/License
/usr/lib/obs/server/README
/usr/lib/obs/server/TODO
/usr/lib/obs/server/XML
/usr/lib/obs/server/Meta.pm
/usr/lib/obs/server/Meta
/usr/lib/obs/server/bs_admin
/usr/lib/obs/server/bs_dispatch
/usr/lib/obs/server/bs_localkiwiworker
/usr/lib/obs/server/bs_publish
/usr/lib/obs/server/bs_repserver
/usr/lib/obs/server/bs_sched
/usr/lib/obs/server/bs_srcserver
/usr/lib/obs/server/bs_worker
/usr/lib/obs/server/build
/usr/lib/obs/server/worker
/usr/lib/obs/server/BSHermes.pm
/usr/lib/obs/server/BSSolv.pm
/usr/lib/obs/server/BSSolv.xs
/usr/lib/obs/server/typemap
%attr(-,obsrun,obsrun) /srv/obs
/var/adm/fillup-templates/sysconfig.obs-server

%files -n obs-sourceservice-svn
%defattr(-,root,root)
/usr/lib/obs/server/bs_service
/usr/lib/obs/server/call-service-in-lxc.sh

%files -n osc-obs
%defattr(-,root,root)
%doc src/clientlib/python/osc/{AUTHORS,README,TODO,NEWS}
%doc %_mandir/man1/osc.*
%{_bindir}/osc*
%{python_sitelib}/*
%{_sysconfdir}/profile.d/*
%if 0%{?suse_version} > 1110
%dir %{_prefix}/lib/osc
%{_prefix}/lib/osc/*
%else
%dir %{_prefix}/%{_lib}/osc
%{_prefix}/%{_lib}/osc/*
%endif
%dir /var/lib/osc-plugins

%files -n build-obs
%defattr(-,root,root)
%doc src/build/README
/usr/bin/build
/usr/bin/buildvc
/usr/bin/unrpm
/usr/lib/build
%{_mandir}/man1/build.1*

%files -n obs-worker-svn
%defattr(-,root,root)
/var/adm/fillup-templates/sysconfig.obs-worker
/etc/init.d/obsworker
/usr/sbin/rcobsworker

%files -n obs-api-svn
%defattr(-,root,root)
%doc dist/{TODO,README.UPDATERS,README.SETUP} docs/openSUSE.org.xml ReleaseNotes-* README COPYING
%doc /srv/www/obs/*/README*
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
/srv/www/obs/frontend/script
/srv/www/obs/frontend/test
/srv/www/obs/frontend/vendor
%dir /srv/www/obs/webclient
/srv/www/obs/webclient/app
/srv/www/obs/webclient/Changelog
/srv/www/obs/webclient/db
/srv/www/obs/webclient/doc
/srv/www/obs/webclient/lib
/srv/www/obs/webclient/public
/srv/www/obs/webclient/Rakefile
/srv/www/obs/webclient/script
/srv/www/obs/webclient/test
/srv/www/obs/webclient/vendor
%config(noreplace) /srv/www/obs/frontend/config
%config(noreplace) /srv/www/obs/webclient/config
%dir %attr(-,lighttpd,lighttpd) /srv/www/obs/frontend/log
%dir %attr(-,lighttpd,lighttpd) /srv/www/obs/webclient/log
%verify(not size md5) %attr(0640,lighttpd,lighttpd) /srv/www/obs/frontend/log/development.log
%verify(not size md5) %attr(0640,lighttpd,lighttpd) /srv/www/obs/webclient/log/development.log
%attr(-,lighttpd,lighttpd) /srv/www/obs/frontend/tmp
%attr(-,lighttpd,lighttpd) /srv/www/obs/webclient/tmp
%config(noreplace) /etc/lighttpd/vhosts.d/obs.conf
%config /etc/lighttpd/cleanurl-v5.lua
%config /etc/lighttpd/vhosts.d/rails.inc

%files -n obs-signd-svn
%defattr(-,root,root)
%config(noreplace) /etc/sign.conf
/usr/sbin/signd
/usr/sbin/rcobssignd
/etc/init.d/obssignd
%{_mandir}/man5/*
%{_mandir}/man8/sign*

%files -n obs-utils-svn
%defattr(-,root,root)
/usr/sbin/obs_mirror_project
/usr/sbin/obs_mirror_project.py
/usr/sbin/obs_project_update
/usr/sbin/obs_project_srcimport

%files -n obs-productconverter-svn
%defattr(-,root,root)
/usr/lib/obs/server/bs_productconvert

%changelog
