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


Name:           obs-bundled-gems
Version:        2.10~pre
Release:        0
Summary:        The Open Build Service -- Bundled Gems
# The actual license is from the gems, but we take a more restrictive
# license to bundle them. Most are MIT anyway (TODO for Ana: check)
License:        GPL-2.0-only OR GPL-3.0-only
Group:          Productivity/Networking/Web/Utilities
Url:            http://www.openbuildservice.org
Source0:        Gemfile
Source1:        Gemfile.lock
Source2:        gem_build_cleanup.sh
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
BuildRequires:  make
BuildRequires:  mysql-devel
BuildRequires:  nodejs
BuildRequires:  python-devel
%if 0%{?suse_version}
%define __obs_ruby_version 2.5.0
%define __obs_ruby_interpreter /usr/bin/ruby.ruby2.5
BuildRequires:  ruby2.5-devel
BuildRequires:  rubygem(ruby:%{__obs_ruby_version}:bundler)
BuildRequires:  openldap2-devel
%else
%define __obs_ruby_version 2.6.0
%define __obs_ruby_interpreter /usr/bin/ruby
BuildRequires:  ruby-devel
BuildRequires:  rubygem-bundler
BuildRequires:  openldap-devel
%endif
BuildRequires:  chrpath

BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
This package bundles all the gems required by the Open Build Service
to make it easier to deploy the obs-server package.

%define rake_version 13.0.6
%define rack_version 2.2.3

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
Requires:       rubygem(ruby:%{__obs_ruby_version}:bundler)
Requires:       rubygem(ruby:%{__obs_ruby_version}:rake:%{rake_version})
Requires:       rubygem(ruby:%{__obs_ruby_version}:rack:%{rack_version})
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

cp %{S:0} %{S:1} .

# copy gem files into cache
mkdir -p vendor/cache
cp %{_sourcedir}/vendor/cache/*.gem vendor/cache

%build
# emtpy since bundle does not decouple compile and install

%install
# all operations here since bundle does not decouple compile and install
export GEM_HOME=~/.gems
bundle config build.ffi --enable-system-libffi
bundle config build.nokogiri --use-system-libraries
bundle config build.sassc --disable-march-tune-native
bundle config build.nio4r --with-cflags='%{optflags} -Wno-return-type'

bundle --local --path %{buildroot}%_libdir/obs-api/

# test that the rake and rack macros is still matching our Gemfile
test -f %{buildroot}%_libdir/obs-api/ruby/%{__obs_ruby_version}/gems/rake-%{rake_version}/rake.gemspec
test -f %{buildroot}%_libdir/obs-api/ruby/%{__obs_ruby_version}/gems/rack-%{rack_version}/rack.gemspec

# run gem clean up script
chmod 755 %{S:2}
%{S:2}  %{buildroot}%_libdir/obs-api/ruby/*/

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

# fix interpreter in installed binaries
for bin in %{buildroot}%_libdir/obs-api/ruby/*/bin/*; do
  sed -i -e 's,/usr/bin/env ruby.ruby2.5,%{__obs_ruby_interpreter},' $bin
done

# remove exec bit from all other files still containing /usr/bin/env - mostly helper scripts
find %{buildroot} -type f -print0 | xargs -0 grep -l /usr/bin/env | while read file; do
  chmod a-x $file
done

# remove the rpath entry from the shared lib in the mysql2 rubygem
chrpath -d %{buildroot}%_libdir/obs-api/ruby/*/extensions/*/*/mysql2-*/mysql2/mysql2.so || true
chrpath -d %{buildroot}%_libdir/obs-api/ruby/*/gems/mysql2-*/lib/mysql2/mysql2.so || true

%files
%_libdir/obs-api

%changelog
