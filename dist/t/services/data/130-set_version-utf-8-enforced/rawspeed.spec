#
# spec file for package rawspeed
#
# Copyright (c) 2017 SUSE LINUX Products GmbH, Nuernberg, Germany.
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

Name:           rawspeed
Version:        0
Release:        0
License:        LGPL-2.1
Summary:        Fast raw decoding library
Url:            https://github.com/darktable-org/rawspeed
Group:          System/Libraries
Source:         %{name}-%{version}.tar.xz
BuildRequires:  cmake >= 3
BuildRequires:  gcc-c++ >= 4.9
BuildRequires:  libxml2-tools
BuildRequires:  pkgconfig
BuildRequires:  pugixml-devel
BuildRequires:  libjpeg-devel
BuildRequires:  zlib-devel
BuildRequires:  googletest-source
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
RawSpeed…

- is capable of decoding various images in RAW file format.
- is intended to provide the fastest decoding speed possible.
- supports the most common DSLR and similar class brands.
- supplies unmodified RAW data, optionally scaled to 16 bit, or normalized to 0->1 float point data.
- supplies CFA layout for all known cameras.
- provides automatic black level calculation for cameras having such information.
- optionally crops off  “junk” areas of images, containing no valid image information.
- can add support for new cameras by adding definitions to an xml file.
- ~~is extensively crash-tested on broken files~~.
- decodes images from memory, not a file stream. You can use a memory mapped file, but it is rarely faster.
- open source under the LGPL v2 license.

%prep
%setup -q

%build
%cmake -DGOOGLETEST_PATH:PATH=%{_datadir}/googletest-source/ -DBUILD_SHARED_LIBS:BOOL=OFF
make %{?_smp_mflags}

%check
%ctest

%install
%cmake_install

%files
%defattr(-,root,root)
%{_bindir}/rs-identify
%dir %{_datadir}/rawspeed/
%{_datadir}/rawspeed/cameras.xml
%{_datadir}/rawspeed/showcameras.xsl
