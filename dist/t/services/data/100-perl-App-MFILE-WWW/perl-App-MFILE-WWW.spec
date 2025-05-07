#
# spec file for package perl-App-MFILE-WWW
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
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


Name:           perl-App-MFILE-WWW
Version:        0.176
Release:        0
%define cpan_name App-MFILE-WWW
Summary:        Web UI development toolkit with prototype demo app
License:        BSD-3-Clause
Group:          Development/Libraries/Perl
Url:            http://search.cpan.org/dist/App-MFILE-WWW/
Source0:        https://cpan.metacpan.org/authors/id/S/SM/SMITHFARM/%{cpan_name}-%{version}.tar.gz
Source1:        cpanspec.yml
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  perl
BuildRequires:  perl-macros
BuildRequires:  perl(App::CELL) >= 0.222
BuildRequires:  perl(File::ShareDir)
BuildRequires:  perl(HTTP::Request)
BuildRequires:  perl(JSON)
BuildRequires:  perl(LWP::UserAgent)
BuildRequires:  perl(Log::Any::Adapter)
BuildRequires:  perl(Module::Build)
BuildRequires:  perl(Params::Validate) >= 1.06
BuildRequires:  perl(Plack::Builder)
BuildRequires:  perl(Plack::Middleware::Session)
BuildRequires:  perl(Plack::Middleware::StackTrace)
BuildRequires:  perl(Plack::Middleware::Static)
BuildRequires:  perl(Plack::Runner)
BuildRequires:  perl(Plack::Test)
BuildRequires:  perl(Test::Fatal)
BuildRequires:  perl(Test::JSON)
BuildRequires:  perl(Try::Tiny)
BuildRequires:  perl(Web::Machine) >= 0.15
Requires:       perl(App::CELL) >= 0.222
Requires:       perl(File::ShareDir)
Requires:       perl(JSON)
Requires:       perl(LWP::UserAgent)
Requires:       perl(Log::Any::Adapter)
Requires:       perl(Params::Validate) >= 1.06
Requires:       perl(Plack::Builder)
Requires:       perl(Plack::Middleware::Session)
Requires:       perl(Plack::Middleware::StackTrace)
Requires:       perl(Plack::Middleware::Static)
Requires:       perl(Plack::Runner)
Requires:       perl(Try::Tiny)
Requires:       perl(Web::Machine) >= 0.15
%{perl_requires}

%description
This distro contains a foundation/framework/toolkit for developing the
"front end" portion of web applications.

App::MFILE::WWW is a Plack application that provides a HTTP
request-response handler (based on Web::Machine), CSS and HTML source code
for an in-browser "screen", and JavaScript code for displaying various
"widgets" (menus, forms, etc.) in that screen and for processing user input
from within those widgets.

In addition, infrastructure is included (but need not be used) for user
authentication, session management, and communication with a backend server
via AJAX calls.

Front ends built with App::MFILE::WWW will typicaly be menu-driven,
consisting exclusively of fixed-width Unicode text, and capable of being
controlled from the keyboard, without the use of a mouse. The overall
look-and-feel is reminiscent of the text terminal era.

The distro comes with a prototype (demo) application to illustrate how the
various widgets are used.

%prep
%setup -q -n %{cpan_name}-%{version}

%build
%{__perl} Build.PL installdirs=vendor
./Build build flags=%{?_smp_mflags}

%check
./Build test

%install
./Build install destdir=%{buildroot} create_packlist=0
%perl_gen_filelist

%files -f %{name}.files
%defattr(-,root,root,755)
%doc Changes README.rst share
%license COPYING LICENSE

%changelog
