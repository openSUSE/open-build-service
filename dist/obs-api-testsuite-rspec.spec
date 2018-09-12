#
# spec file for package obs-api-testsuite-rspec
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


Name:           obs-api-testsuite-rspec
Version:        2.10~pre
Release:        0
Summary:        The Open Build Service -- RSpec test suite
License:        GPL-2.0-only
Group:          Productivity/Networking/Web/Utilities
Url:            http://www.openbuildservice.org
Source0:        open-build-service-%version.tar.xz
BuildRequires:  obs-api-testsuite-deps
# rspec specific dependencies
BuildRequires:  chromedriver
BuildRequires:  xorg-x11-fonts
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
%if 0%{?disable_obs_frontend_test_suite} || 0%{?disable_obs_test_suite}
ExclusiveArch:  nothere
%else
ExclusiveArch:  x86_64
%endif


%description
Running the RSpec test suite of the OBS frontend independently
of packaging the application

%prep
%setup -q -n open-build-service-%{version}

%build
# run in build environment
pushd src/backend/
rm -rf build
ln -sf /usr/lib/build build
popd

pushd src/api
# configure to the bundled gems
bundle --local --path %_libdir/obs-api/

./script/prepare_spec_tests.sh

export RAILS_ENV=test
bin/rake db:create db:setup
bin/rails assets:precompile

#without boostrap
bin/rspec -f d --exclude-pattern "spec/bootstrap/**/*_spec.rb"

#only bootstrap
BOOTSTRAP=1 bin/rspec -f d spec/bootstrap/

%install

# no result
%files

%changelog
