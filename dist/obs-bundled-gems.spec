#
# spec file for package obs-bundled-gems
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.
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

%if 0%{?suse_version}
%define __obs_ruby_interpreter /usr/bin/ruby.ruby3.4
%define rack_version %(%{__obs_ruby_interpreter} -r rack -e "puts Rack::RELEASE")
%define rake_version %(%{__obs_ruby_interpreter} -r rake -e "puts Rake::VERSION")
%define ruby_abi_version %(%{__obs_ruby_interpreter} -r rbconfig -e 'print RbConfig::CONFIG["ruby_version"]')
%else
%define __obs_ruby_interpreter /usr/bin/ruby
%endif

Name:           obs-bundled-gems
Version:        2.10~pre
Release:        0
Summary:        The Open Build Service -- Bundled Gems
# The actual license is from the gems, but we take a more restrictive
# license to bundle them. Most are MIT anyway (TODO for Ana: check)
License:        GPL-2.0-only OR GPL-3.0-only
Group:          Productivity/Networking/Web/Utilities
Url:            http://www.openbuildservice.org
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  cyrus-sasl-devel
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  glibc-devel
BuildRequires:  libtool
BuildRequires:  libffi-devel
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
BuildRequires:  libyaml-devel
BuildRequires:  make
BuildRequires:  mysql-devel
BuildRequires:  nodejs
%if 0%{?suse_version}
BuildRequires:  ruby3.4-devel
BuildRequires:  openldap2-devel
# For comparing package/bundle versions with make test_rack
BuildRequires:  rubygem(ruby:3.4.0:rack)
%else
BuildRequires:  ruby-devel
BuildRequires:  rubygem-bundler
BuildRequires:  openldap-devel
%endif
BuildRequires:  chrpath
PreReq: permissions

BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
This package bundles all the gems required by the Open Build Service
to make it easier to deploy the obs-server package.

%package -n obs-api-deps
Summary:        Holding dependencies required to run the OBS frontend
Group:          Productivity/Networking/Web/Utilities
%if 0%{?suse_version}
Requires:       build >= 20170315
%else
Requires:       obs-build
%endif
Requires:       memcached >= 1.4
Requires:       mysql
Requires:       obs-bundled-gems = %{version}
Requires:       sphinx >= 2.2.11
Requires:       perl(GD)
%if 0%{?suse_version}
Requires:       rubygem(ruby:3.4.0:rack) = %{rack_version}
Requires:       rubygem(ruby:3.4.0:rake) = %{rake_version}
%else
Requires:       rubygem-bundler
Requires:       rubygem-rake
Requires:       rubygem-rack
%endif
%description -n obs-api-deps
To simplify splitting the test suite packages off the main package,
this package is just a meta package used to run and build obs-api

%files -n obs-api-deps
%doc README

%package -n obs-api-testsuite-deps
Summary:        Holding dependencies required to run frontend test suites
Group:          Productivity/Networking/Web/Utilities
%if 0%{?suse_version}
Requires:       inst-source-utils
%endif
Requires:       nodejs
Requires:       obs-api-deps = %{version}

%description -n obs-api-testsuite-deps
To simplify splitting the test suite packages off the main package,
this package is just a meta package used to build obs-api testsuite

%files -n obs-api-testsuite-deps
%doc README

%prep
echo > README <<EOF
This package is just a meta package containing requires
EOF

%build
# emtpy since bundle does not decouple compile and install

%install
# all operations here since bundle does not decouple compile and install
pushd %{_sourcedir}/open-build-service-*/src/api
export GEM_HOME=~/.gems
bundle config build.ffi --enable-system-libffi
bundle config build.nokogiri --use-system-libraries
bundle config build.sassc --disable-march-tune-native
bundle config build.nio4r --with-cflags='%{optflags} -Wno-return-type'
bundle config force_ruby_platform true
bundle config set path %{buildroot}%_libdir/obs-api/

bundle install --local
popd

%if 0%{?suse_version}
pushd %{_sourcedir}/open-build-service-*/src/api
# test that the rack/rake bundle versions are matching the system versions
make test_rack
make test_rake
popd
%endif

pushd %{_sourcedir}/open-build-service-*/dist
# run gem clean up script
chmod 755 gem_build_cleanup.sh
./gem_build_cleanup.sh  %{buildroot}%_libdir/obs-api/ruby/*/
popd

# Remove sources of extensions, we don't need them
%if 0%{?suse_version}
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/*/ext/
%endif

# remove binaries with invalid interpreters
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/diff-lcs-*/bin

# remove spec / test files from gems as they shouldn't be shipped in gems anyway
# and often cause errors / warning in rpmlint
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/*/spec/
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/*/test/

# remove prebuilt binaries causing broken dependencies
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/selenium-webdriver-*/lib/selenium/webdriver/firefox/native

# remove all gitignore files to fix rpmlint version-control-internal-file
find %{buildroot}%_libdir/obs-api -name .gitignore | xargs rm -rf
find %{buildroot}%_libdir/obs-api -name .cvsignore | xargs rm -rf

# use the ruby interpreter set by this spec file in all installed ruby scripts
for bin in %{buildroot}%_libdir/obs-api/ruby/*/bin/*; do
  sed -i -e '1!b;s,^#!.*/bin/ruby.*$,#!%{__obs_ruby_interpreter},' $bin
  sed -i -e '1!b;s,^#!.*/bin/env ruby.*$,#!%{__obs_ruby_interpreter},' $bin
done
for bin in %{buildroot}%_libdir/obs-api/ruby/*/gems/*/bin/*; do
  # Some gems have subdirectories inside bin, so we skip them
  if [[ -f $bin ]]; then
    sed -i -e '1!b;s,^#!/usr/bin/ruby.*$,#!%{__obs_ruby_interpreter},' $bin
    sed -i -e '1!b;s,^#!/usr/bin/env ruby.*$,#!%{__obs_ruby_interpreter},' $bin
  fi
done
# And here process those binaries in subdirectories
for bin in %{buildroot}%_libdir/obs-api/ruby/*/gems/*/bin/linux/*; do
  sed -i -e '1!b;s,^#!/usr/bin/ruby.*$,#!%{__obs_ruby_interpreter},' $bin
  sed -i -e '1!b;s,^#!/usr/bin/env ruby.*$,#!%{__obs_ruby_interpreter},' $bin
done

# remove exec bit from all other files still containing /usr/bin/env - mostly helper scripts
find %{buildroot} -type f -print0 | xargs -0 grep -l /usr/bin/env | while read file; do
  chmod a-x $file
done

# remove the rpath entry from the shared lib in the mysql2 rubygem
chrpath -d %{buildroot}%_libdir/obs-api/ruby/*/extensions/*/*/mysql2-*/mysql2/mysql2.so || true
chrpath -d %{buildroot}%_libdir/obs-api/ruby/*/gems/mysql2-*/lib/mysql2/mysql2.so || true

%files
%defattr(-,root,root,755)
%_libdir/obs-api

%changelog
