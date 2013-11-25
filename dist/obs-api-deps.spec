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
Version:        20131125143051.d0638692
Release:        0
Url:            http://en.opensuse.org/Build_Service
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        update-sources.sh

%description
This package serves one purpose only: to list the dependencies in Gemfile.lock

%package -n obs-api-testsuite-deps
Summary:        The Open Build Service -- The Testsuite dependencies
Group:          Productivity/Networking/Web/Utilities
# dependencies not needed in production
# OBS_TESTSUITE_BEGIN
Requires:       rubygem(2.0.0:actionmailer) = 4.0.1
Requires:       rubygem(2.0.0:actionpack) = 4.0.1
Requires:       rubygem(2.0.0:activemodel) = 4.0.1
Requires:       rubygem(2.0.0:activerecord) = 4.0.1
Requires:       rubygem(2.0.0:activerecord-deprecated_finders) = 1.0.3
Requires:       rubygem(2.0.0:activesupport) = 4.0.1
Requires:       rubygem(2.0.0:addressable) = 2.3.5
Requires:       rubygem(2.0.0:arel) = 4.0.1
Requires:       rubygem(2.0.0:atomic) = 1.1.14
Requires:       rubygem(2.0.0:bootstrap-sass-rails) = 3.0.2.1
Requires:       rubygem(2.0.0:builder) = 3.1.4
Requires:       rubygem(2.0.0:capybara) = 2.1.0
Requires:       rubygem(2.0.0:capybara_minitest_spec) = 1.0.1
Requires:       rubygem(2.0.0:chunky_png) = 1.2.9
Requires:       rubygem(2.0.0:ci_reporter) = 1.9.0
Requires:       rubygem(2.0.0:cliver) = 0.2.2
Requires:       rubygem(2.0.0:clockwork) = 0.7.0
Requires:       rubygem(2.0.0:codemirror-rails) = 3.16
Requires:       rubygem(2.0.0:coderay) = 1.1.0
Requires:       rubygem(2.0.0:crack) = 0.4.1
Requires:       rubygem(2.0.0:cssmin) = 1.0.3
Requires:       rubygem(2.0.0:daemons) = 1.1.9
Requires:       rubygem(2.0.0:dalli) = 2.6.4
Requires:       rubygem(2.0.0:database_cleaner) = 1.2.0
Requires:       rubygem(2.0.0:delayed_job) = 4.0.0
Requires:       rubygem(2.0.0:delayed_job_active_record) = 4.0.0
Requires:       rubygem(2.0.0:docile) = 1.1.0
Requires:       rubygem(2.0.0:erubis) = 2.7.0
Requires:       rubygem(2.0.0:escape_utils) = 1.0.0
Requires:       rubygem(2.0.0:execjs) = 2.0.2
Requires:       rubygem(2.0.0:faker) = 1.2.0
Requires:       rubygem(2.0.0:flog) = 4.2.0
Requires:       rubygem(2.0.0:font-awesome-rails) = 4.0.3.0
Requires:       rubygem(2.0.0:haml) = 4.0.4
Requires:       rubygem(2.0.0:hike) = 1.2.3
Requires:       rubygem(2.0.0:hoptoad_notifier) = 2.4.11
Requires:       rubygem(2.0.0:i18n) = 0.6.5
Requires:       rubygem(2.0.0:innertube) = 1.1.0
Requires:       rubygem(2.0.0:jquery-datatables-rails) = 1.12.2
Requires:       rubygem(2.0.0:jquery-rails) = 3.0.4
Requires:       rubygem(2.0.0:jquery-ui-rails) = 4.1.0
Requires:       rubygem(2.0.0:json) = 1.8.1
Requires:       rubygem(2.0.0:kaminari) = 0.15.0
Requires:       rubygem(2.0.0:kgio) = 2.8.1
Requires:       rubygem(2.0.0:mail) = 2.5.4
Requires:       rubygem(2.0.0:metaclass) = 0.0.1
Requires:       rubygem(2.0.0:method_source) = 0.8.2
Requires:       rubygem(2.0.0:middleware) = 0.1.0
Requires:       rubygem(2.0.0:mime-types) = 1.25
Requires:       rubygem(2.0.0:mini_portile) = 0.5.2
Requires:       rubygem(2.0.0:minitest) = 4.7.4
Requires:       rubygem(2.0.0:minitest-colorize) = 0.0.5
Requires:       rubygem(2.0.0:mocha) = 0.14.0
Requires:       rubygem(2.0.0:multi_json) = 1.8.2
Requires:       rubygem(2.0.0:mysql2) = 0.3.14
Requires:       rubygem(2.0.0:newrelic_rpm) = 3.6.9.171
Requires:       rubygem(2.0.0:nokogiri) = 1.6.0
Requires:       rubygem(2.0.0:pkg-config) = 1.1.4
Requires:       rubygem(2.0.0:poltergeist) = 1.4.1
Requires:       rubygem(2.0.0:polyglot) = 0.3.3
Requires:       rubygem(2.0.0:pry) = 0.9.12.4
Requires:       rubygem(2.0.0:rack) = 1.5.2
Requires:       rubygem(2.0.0:rack-mini-profiler) = 0.1.31
Requires:       rubygem(2.0.0:rack-test) = 0.6.2
Requires:       rubygem(2.0.0:rails) = 4.0.1
Requires:       rubygem(2.0.0:rails_tokeninput) = 1.6.1.rc1
Requires:       rubygem(2.0.0:railties) = 4.0.1
Requires:       rubygem(2.0.0:raindrops) = 0.12.0
Requires:       rubygem(2.0.0:rake) = 10.1.0
Requires:       rubygem(2.0.0:rdoc) = 4.0.1
Requires:       rubygem(2.0.0:riddle) = 1.5.9
Requires:       rubygem(2.0.0:ruby-ldap) = 0.9.16
Requires:       rubygem(2.0.0:ruby_parser) = 3.2.2
Requires:       rubygem(2.0.0:safe_yaml) = 0.9.7
Requires:       rubygem(2.0.0:sass) = 3.2.12
Requires:       rubygem(2.0.0:sass-rails) = 4.0.1
Requires:       rubygem(2.0.0:sexp_processor) = 4.4.0
Requires:       rubygem(2.0.0:simplecov) = 0.8.2
Requires:       rubygem(2.0.0:simplecov-html) = 0.8.0
Requires:       rubygem(2.0.0:slop) = 3.4.7
Requires:       rubygem(2.0.0:sprite-factory) = 1.5.3
Requires:       rubygem(2.0.0:sprockets) = 2.10.1
Requires:       rubygem(2.0.0:sprockets-rails) = 2.0.1
Requires:       rubygem(2.0.0:thinking-sphinx) = 3.0.6
Requires:       rubygem(2.0.0:thor) = 0.18.1
Requires:       rubygem(2.0.0:thread_safe) = 0.1.3
Requires:       rubygem(2.0.0:tilt) = 1.4.1
Requires:       rubygem(2.0.0:timecop) = 0.6.3
Requires:       rubygem(2.0.0:treetop) = 1.4.15
Requires:       rubygem(2.0.0:tzinfo) = 0.3.37
Requires:       rubygem(2.0.0:uglifier) = 2.3.1
Requires:       rubygem(2.0.0:unicorn) = 4.7.0
Requires:       rubygem(2.0.0:unicorn-rails) = 1.1.0
Requires:       rubygem(2.0.0:webmock) = 1.16.0
Requires:       rubygem(2.0.0:websocket-driver) = 0.3.0
Requires:       rubygem(2.0.0:xmlhash) = 1.3.6
Requires:       rubygem(2.0.0:xpath) = 2.0.0
Requires:       rubygem(2.0.0:yajl-ruby) = 1.1.0
# OBS_TESTSUITE_END

Requires:       perl-BSSolv >= 0.18.0
# Required by source server
Requires:       createrepo
Requires:       diffutils
Requires:       git-core
Requires:       patch

# needed for api test suite
Requires:       libxml2-tools

Recommends:     yum yum-metadata-parser repoview dpkg
Recommends:     deb >= 1.5
Recommends:     lvm2
Recommends:     openslp-server
Recommends:     obs-signd
Recommends:     inst-source-utils
Requires:       perl-Compress-Zlib
Requires:       perl-File-Sync >= 0.10
Requires:       perl-Net-SSLeay
Requires:       perl-Socket-MsgHdr
Requires:       perl-XML-Parser
Requires:       perl-JSON-XS
Requires:       sphinx
Conflicts:      sphinx < 2.0.8

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
