#
# spec file for package perl-Web-MREST
#
# Copyright (c) 2016 SUSE LINUX GmbH, Nuernberg, Germany.
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


Name:           perl-Web-MREST
Version:        0.286
Release:        0
%define cpan_name Web-MREST
Summary:        Minimalistic REST server
License:        BSD-3-Clause
Group:          Development/Libraries/Perl
Url:            http://search.cpan.org/dist/Web-MREST/
Source0:        http://www.cpan.org/authors/id/S/SM/SMITHFARM/%{cpan_name}-%{version}.tar.gz
Source1:        cpanspec.yml
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  perl
BuildRequires:  perl-macros
BuildRequires:  perl(App::CELL) >= 0.209
BuildRequires:  perl(File::ShareDir)
BuildRequires:  perl(HTTP::Request)
BuildRequires:  perl(HTTP::Request::Common)
BuildRequires:  perl(JSON)
BuildRequires:  perl(LWP::Protocol::https) >= 6.04
BuildRequires:  perl(LWP::UserAgent) >= 6.05
BuildRequires:  perl(Module::Build)
BuildRequires:  perl(Module::Runtime)
BuildRequires:  perl(Params::Validate) >= 1.06
BuildRequires:  perl(Path::Router) >= 0.12
BuildRequires:  perl(Plack) >= 1.0031
BuildRequires:  perl(Plack::Middleware::LogErrors)
BuildRequires:  perl(Plack::Middleware::Session)
BuildRequires:  perl(Plack::Middleware::StackTrace)
BuildRequires:  perl(Plack::Runner)
BuildRequires:  perl(Plack::Session)
BuildRequires:  perl(Plack::Test)
BuildRequires:  perl(Pod::Simple::HTML)
BuildRequires:  perl(Pod::Simple::Text)
BuildRequires:  perl(Test::Deep)
BuildRequires:  perl(Test::Deep::NoTest)
BuildRequires:  perl(Test::Fatal)
BuildRequires:  perl(Test::JSON)
BuildRequires:  perl(Test::Warnings)
BuildRequires:  perl(Try::Tiny)
BuildRequires:  perl(URI::Escape)
BuildRequires:  perl(Web::MREST::CLI) >= 0.276
BuildRequires:  perl(Web::Machine) >= 0.15
Requires:       perl(App::CELL) >= 0.205
Requires:       perl(File::ShareDir)
Requires:       perl(HTTP::Request)
Requires:       perl(HTTP::Request::Common)
Requires:       perl(JSON)
Requires:       perl(LWP::Protocol::https) >= 6.04
Requires:       perl(LWP::UserAgent) >= 6.05
Requires:       perl(Module::Runtime)
Requires:       perl(Params::Validate) >= 1.06
Requires:       perl(Path::Router) >= 0.12
Requires:       perl(Plack::Middleware::LogErrors)
Requires:       perl(Plack::Middleware::Session)
Requires:       perl(Plack::Middleware::StackTrace)
Requires:       perl(Plack::Runner)
Requires:       perl(Plack::Session)
Requires:       perl(Pod::Simple::HTML)
Requires:       perl(Pod::Simple::Text)
Requires:       perl(Test::Deep::NoTest)
Requires:       perl(Try::Tiny)
Requires:       perl(URI::Escape)
Requires:       perl(Web::MREST::CLI) >= 0.276
Requires:       perl(Web::Machine) >= 0.15
%{perl_requires}

%description
MREST stands for "minimalistic" or "mechanical" REST server. (Mechanical
because it relies on Web::Machine.)

Web::MREST provides a fully functional REST server that can be started with
a simple command. Without modification, the server provides a set of
generalized resources that can be used to demonstrate how the REST server
works, or for testing.

Developers can use Web::MREST as a platform for implementing their own REST
servers, as described below. App::Dochazka::REST is a "real-world" example
of such a server.

For an introduction to REST and Web Services, see
Web::MREST::WebServicesIntro.

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
%doc Changes config LICENSE README.rst

%changelog
