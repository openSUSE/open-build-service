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

%define rack_version 2.2.20
%define rake_version 13.0.1

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
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
BuildRequires:  libffi-devel
BuildRequires:  make
BuildRequires:  mysql-devel
BuildRequires:  nodejs
BuildRequires:  openldap2-devel
BuildRequires:  python-devel
BuildRequires:  ruby2.7-devel
BuildRequires:  chrpath

BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
This package bundles all the gems required by the Open Build Service
to make it easier to deploy the obs-server package.

%package -n obs-api-deps
Summary:        Holding dependencies required to run the OBS frontend
Group:          Productivity/Networking/Web/Utilities
Requires:       build >= 20170315
Requires:       memcached >= 1.4
Requires:       mysql
Requires:       obs-bundled-gems = %{version}
Requires:       sphinx >= 2.1.8
Requires:       perl(GD)
Requires:       rubygem(ruby:2.7.0:rack) = %{rack_version}

%description -n obs-api-deps
To simplify splitting the test suite packages off the main package,
this package is just a meta package used to run and build obs-api

%files -n obs-api-deps
%doc README

%package -n obs-api-testsuite-deps
Summary:        Holding dependencies required to run frontend test suites
Group:          Productivity/Networking/Web/Utilities
Requires:       inst-source-utils
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
bundle config build.nio4r --with-cflags='%{optflags} -Wno-return-type'
bundle config force_ruby_platform true

bundle --local --path %{buildroot}%_libdir/obs-api/
popd

# Make sure rake and rack in Gemfile.lock match the versions from the
# rubygem-rack and ruby2.7 packages
# otherwise Passenger wont start the app

test -f %{buildroot}%_libdir/obs-api/ruby/2.7.0/gems/rack-%{rack_version}/rack.gemspec
test -f %{buildroot}%_libdir/obs-api/ruby/2.7.0/gems/rake-%{rake_version}/rake.gemspec

# run gem clean up script
/usr/lib/rpm/gem_build_cleanup.sh %{buildroot}%_libdir/obs-api/ruby/*/

# work around sassc bug - and install libsass
sassc_dir=$(ls -1d %{buildroot}%_libdir/obs-api/ruby/2.7.0/gems/sassc-2*)
install -D -m 755 $sassc_dir/ext/libsass/lib/libsass.so $sassc_dir/lib
sed -i -e 's,/ext/libsass,,' $sassc_dir/lib/sassc/native.rb

# Remove sources of extensions, we don't need them
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/*/ext/

# remove binaries with invalid interpreters
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/diff-lcs-*/bin

# remove spec / test files from gems as they shouldn't be shipped in gems anyway
# and often cause errors / warning in rpmlint
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/*/spec/
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/*/test/
# we do not verify signing of the gem
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/mousetrap-rails-*/gem-public_cert.pem

# remove prebuilt binaries causing broken dependencies
rm -rf %{buildroot}%_libdir/obs-api/ruby/*/gems/selenium-webdriver-*/lib/selenium/webdriver/firefox/native

# remove all gitignore files to fix rpmlint version-control-internal-file
find %{buildroot}%_libdir/obs-api -name .gitignore | xargs rm -rf

# fix interpreter in installed binaries
for bin in %{buildroot}%_libdir/obs-api/ruby/*/bin/*; do
  sed -i -e 's,/usr/bin/env ruby.ruby2.7,/usr/bin/ruby.ruby2.7,' $bin
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
