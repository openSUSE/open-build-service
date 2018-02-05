#
# spec file for package obs-api-deps
#
# Copyright (c) 2014 SUSE LINUX Products GmbH, Nuernberg, Germany.
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


Name:           obs-api-deps
Summary:        The Open Build Service -- Gem dependencies
License:        MIT
Group:          Productivity/Networking/Web/Utilities
Version:        2.7.5020140303
Release:        0
Url:            http://en.opensuse.org/Build_Service
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        open-build-service-%version.tar.xz
Source1:        find-requires.sh
BuildRequires:  ruby2.5
BuildRequires:  ruby2.5-rubygem-bundler
%if 0%{?suse_version} < 1210
BuildRequires:  xz
%endif

%description
This package serves one purpose only: to list the dependencies in Gemfile.lock

%package -n obs-api-testsuite-deps
Summary:        The Open Build Service -- The Testsuite dependencies
Group:          Productivity/Networking/Web/Utilities
# dependencies not needed in production
Requires:       %(echo `bash %{S:1} %{S:0} "ruby:2.4.0"`)

Requires:       perl-BSSolv >= 0.18.0
# Required by source server
Requires:       createrepo
Requires:       diffutils
Requires:       git-core
Requires:       patch

# needed for api test suite
%if 0%{suse_version} > 1210
Requires:       libxml2-tools
%else
Requires:       libxml2
%endif

Recommends:     yum yum-metadata-parser repoview dpkg
Recommends:     deb >= 1.5
Recommends:     lvm2
Recommends:     openslp-server
Recommends:     obs-signd
Recommends:     inst-source-utils
Requires:       perl-Compress-Zlib
Requires:       perl-File-Sync >= 0.10
Requires:       perl-JSON-XS
Requires:       perl-Net-SSLeay
Requires:       perl-Socket-MsgHdr
Requires:       perl-XML-Parser
Requires:       perl-XML-Simple
Requires:       perl(GD)
Requires:       sphinx >= 2.1.8

%description -n obs-api-testsuite-deps
This is the API server instance, and the web client for the
OBS.

%prep
echo > README <<EOF
This is just a meta package with requires
EOF

%build

%install

# main package is .src.rpm only

%files -n obs-api-testsuite-deps
%defattr(-,root,root)
%doc README

%changelog
