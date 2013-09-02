#
# spec file for package obs-api-deps
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
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
Version:        20130307152043.
Release:        0
Url:            http://en.opensuse.org/Build_Service
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        update-sources.sh

%description
This package serves one purpose only: to list the dependencies in Gemfile.lock

%package -n obs-api-testsuite-deps
Summary:        The Open Build Service -- The Testsuite dependencies
Group:          Productivity/Networking/Web/Utilities
Requires:       perl-Compress-Zlib
Requires:       perl-File-Sync >= 0.10
Requires:       perl-Net-SSLeay
Requires:       perl-Socket-MsgHdr
Requires:       perl-XML-Parser
Requires:       perl-JSON-XS
Requires:       perl-BSSolv >= 0.18.0
# dependencies not needed in production
# OBS_TESTSUITE_BEGIN
Requires:       rubygem(1.9.1:actionmailer) = 3.2.12
Requires:       rubygem(1.9.1:actionpack) = 3.2.12
Requires:       rubygem(1.9.1:activemodel) = 3.2.12
Requires:       rubygem(1.9.1:activerecord) = 3.2.12
Requires:       rubygem(1.9.1:activeresource) = 3.2.12
Requires:       rubygem(1.9.1:activesupport) = 3.2.12
Requires:       rubygem(1.9.1:addressable) = 2.3.2
Requires:       rubygem(1.9.1:arel) = 3.0.2
Requires:       rubygem(1.9.1:builder) = 3.0.4
Requires:       rubygem(1.9.1:capybara) = 2.0.2
Requires:       rubygem(1.9.1:capybara-webkit) = 0.14.1
Requires:       rubygem(1.9.1:capybara_minitest_spec) = 1.0.0
Requires:       rubygem(1.9.1:childprocess) = 0.3.8
Requires:       rubygem(1.9.1:chunky_png) = 1.2.7
Requires:       rubygem(1.9.1:ci_reporter) = 1.8.4
Requires:       rubygem(1.9.1:codemirror-rails) = 3.00
Requires:       rubygem(1.9.1:coderay) = 1.0.8
Requires:       rubygem(1.9.1:compass) = 0.12.2
Requires:       rubygem(1.9.1:compass-rails) = 1.0.3
Requires:       rubygem(1.9.1:crack) = 0.3.2
Requires:       rubygem(1.9.1:cssmin) = 1.0.2
Requires:       rubygem(1.9.1:daemons) = 1.1.9
Requires:       rubygem(1.9.1:database_cleaner) = 0.9.1
Requires:       rubygem(1.9.1:delayed_job) = 3.0.5
Requires:       rubygem(1.9.1:delayed_job_active_record) = 0.3.3
Requires:       rubygem(1.9.1:erubis) = 2.7.0
Requires:       rubygem(1.9.1:execjs) = 1.4.0
Requires:       rubygem(1.9.1:faker) = 1.1.2
Requires:       rubygem(1.9.1:fast_xs) = 0.8.0
Requires:       rubygem(1.9.1:ffi) = 1.3.1
Requires:       rubygem(1.9.1:fssm) = 0.2.10
Requires:       rubygem(1.9.1:headless) = 1.0.0
Requires:       rubygem(1.9.1:hike) = 1.2.1
Requires:       rubygem(1.9.1:hoptoad_notifier) = 2.4.11
Requires:       rubygem(1.9.1:i18n) = 0.6.1
Requires:       rubygem(1.9.1:journey) = 1.0.4
Requires:       rubygem(1.9.1:jquery-datatables-rails) = 1.11.2
Requires:       rubygem(1.9.1:jquery-rails) = 2.1.4
Requires:       rubygem(1.9.1:json) = 1.7.7
Requires:       rubygem(1.9.1:launchy) = 2.1.2
Requires:       rubygem(1.9.1:mail) = 2.4.4
Requires:       rubygem(1.9.1:memcache-client) = 1.8.5
Requires:       rubygem(1.9.1:metaclass) = 0.0.1
Requires:       rubygem(1.9.1:method_source) = 0.8.1
Requires:       rubygem(1.9.1:mime-types) = 1.19
Requires:       rubygem(1.9.1:minitest) = 4.6.0
Requires:       rubygem(1.9.1:mobileesp_converted) = 0.2.1
Requires:       rubygem(1.9.1:mocha) = 0.13.2
Requires:       rubygem(1.9.1:multi_json) = 1.5.0
Requires:       rubygem(1.9.1:mysql2) = 0.3.11
Requires:       rubygem(1.9.1:nokogiri) = 1.5.6
Requires:       rubygem(1.9.1:pkg-config) = 1.1.4
Requires:       rubygem(1.9.1:polyglot) = 0.3.3
Requires:       rubygem(1.9.1:pry) = 0.9.10
Requires:       rubygem(1.9.1:rack) = 1.4.5
Requires:       rubygem(1.9.1:rack-cache) = 1.2
Requires:       rubygem(1.9.1:rack-mini-profiler) = 0.1.23
Requires:       rubygem(1.9.1:rack-ssl) = 1.3.3
Requires:       rubygem(1.9.1:rack-test) = 0.6.2
Requires:       rubygem(1.9.1:rails) = 3.2.12
Requires:       rubygem(1.9.1:rails-api) = 0.0.3
Requires:       rubygem(1.9.1:rails_tokeninput) = 1.6.1.rc1
Requires:       rubygem(1.9.1:railties) = 3.2.12
Requires:       rubygem(1.9.1:rake) = 0.9.2.2
Requires:       rubygem(1.9.1:rdoc) = 3.12
Requires:       rubygem(1.9.1:rubyzip) = 0.9.9
Requires:       rubygem(1.9.1:sass) = 3.2.5
Requires:       rubygem(1.9.1:sass-rails) = 3.2.5
Requires:       rubygem(1.9.1:selenium-webdriver) = 2.29.0
Requires:       rubygem(1.9.1:simplecov) = 0.7.1
Requires:       rubygem(1.9.1:simplecov-html) = 0.7.1
Requires:       rubygem(1.9.1:simplecov-rcov) = 0.2.3
Requires:       rubygem(1.9.1:slop) = 3.3.3
Requires:       rubygem(1.9.1:sprockets) = 2.2.2
Requires:       rubygem(1.9.1:sqlite3) = 1.3.7
Requires:       rubygem(1.9.1:thor) = 0.17.0
Requires:       rubygem(1.9.1:tilt) = 1.3.3
Requires:       rubygem(1.9.1:timecop) = 0.5.9.2
Requires:       rubygem(1.9.1:treetop) = 1.4.12
Requires:       rubygem(1.9.1:tzinfo) = 0.3.35
Requires:       rubygem(1.9.1:uglifier) = 1.3.0
Requires:       rubygem(1.9.1:webmock) = 1.9.0
Requires:       rubygem(1.9.1:websocket) = 1.0.7
Requires:       rubygem(1.9.1:xmlhash) = 1.3.5
Requires:       rubygem(1.9.1:xpath) = 1.0.0
Requires:       rubygem(1.9.1:yajl-ruby) = 1.1.0
# OBS_TESTSUITE_END

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
