include ../../Makefile.include
-include ../../Makefile.local


OBS_API_LOGS := access.log backend_access.log delayed_job.log error.log lastevents.access.log

all:

install: prepare_dirs prepare_rake docs config log_files build

prepare_dirs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_API_PREFIX)
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_API_PREFIX)/log
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_API_PREFIX)/storage
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_API_PREFIX)/tmp
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_API_PREFIX)/config
	# prepare for running sphinx daemon
	$(INSTALL) -m 0755 -d $(DESTDIR)$(OBS_API_PREFIX)/db/sphinx{,/production}

prepare_rake: prepare_dirs
	cp -a * $(DESTDIR)$(OBS_API_PREFIX)
	cp -a .bundle $(DESTDIR)$(OBS_API_PREFIX)
	rm $(DESTDIR)$(OBS_API_PREFIX)/Makefile
	rm $(DESTDIR)$(OBS_API_PREFIX)/Procfile
	touch $(DESTDIR)$(OBS_API_PREFIX)/log/production.log
	touch $(DESTDIR)$(OBS_API_PREFIX)/config/production.sphinx.conf
	sed -i -e 's,#!/usr/bin/ruby.ruby3.4,#!$(OBS_RUBY_BIN),' $(DESTDIR)$(OBS_API_PREFIX)/bin/* $(DESTDIR)$(OBS_API_PREFIX)/script/*
	sed -i -e 's,#!/usr/bin/rake.ruby3.4,#!$(OBS_RAKE_BIN),' $(DESTDIR)$(OBS_API_PREFIX)/Rakefile


docs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_APIDOCS_PREFIX)/api
	cp -av ../../docs/api/api $(DESTDIR)$(OBS_APIDOCS_PREFIX)
	ln -sf $(OBS_APIDOCS_PREFIX)/api/ $(DESTDIR)$(OBS_API_PREFIX)/public/schema
	echo 'CONFIG["schema_location"] ||= File.expand_path("../docs/api/")' >> $(DESTDIR)$(OBS_API_PREFIX)/config/environment.rb

config: prepare_dirs
	# we need config also in building environment, otherwise rake will break
	$(INSTALL) -m 644  config/database.yml.example 				config/database.yml
	$(INSTALL) -m 644  config/options.yml.example 				config/options.yml
	$(INSTALL) -m 644 config/thinking_sphinx.yml.example 	config/thinking_sphinx.yml
	# TODO: see if these configuration work in real life
	$(INSTALL) -m 644  config/database.yml.example 				$(DESTDIR)$(OBS_API_PREFIX)/config/database.yml
	$(INSTALL) -m 644  config/options.yml.example 				$(DESTDIR)$(OBS_API_PREFIX)/config/options.yml
	$(INSTALL) -m 644 config/thinking_sphinx.yml.example 	$(DESTDIR)$(OBS_API_PREFIX)/config/thinking_sphinx.yml
	echo "# This is to prevent fdupes from hardlinking" >> $(DESTDIR)$(OBS_API_PREFIX)/config/database.yml
	echo "# This is to prevent fdupes from hardlinking" >> $(DESTDIR)$(OBS_API_PREFIX)/config/options.yml
	echo "# This is to prevent fdupes from hardlinking" >> $(DESTDIR)$(OBS_API_PREFIX)/config/thinking_sphinx.yml

log_files:
	$(foreach logfile,$(OBS_API_LOGS),$(shell touch $(DESTDIR)$(OBS_API_PREFIX)/log/$(logfile) ))

build: config
	# we need to have *something* as secret key
	echo "" | sha256sum| cut -d\  -f 1 > $(DESTDIR)$(OBS_API_PREFIX)/config/secret.key
	cd $(DESTDIR)$(OBS_API_PREFIX) ;\
	bin/rake assets:precompile RAILS_ENV=production RAILS_GROUPS=assets || exit 1 ;\
	rm -rf tmp/cache/sass tmp/cache/assets config/secret.key ;\
	bin/bundle config --local frozen 1 || exit 1 ;\
	bin/bundle config --local without development:test:assets || exit 1 ;\
	# reinstall
	$(INSTALL) config/database.yml.example $(DESTDIR)$(OBS_API_PREFIX)/config/database.yml
	# patch our version inside
	sed -i -e 's,^api_version.*,api_version = "$(OBS_VERSION)",'  $(DESTDIR)$(OBS_API_PREFIX)/config/initializers/02_apiversion.rb

test_unit:
	[ -d log ] || mkdir log
	echo > log/test.log
	sh -x ./script/prepare_spec_tests.sh
	sh -x ./script/api_minitest.sh
	# rspec runs independently

test_rake:
	$(eval SYSTEM_RAKE_VERSION:=$(shell basename `gem.ruby3.4 which -g rake | sed 's,/lib/rake.rb$$,,'`))
	$(eval BUNDLE_RAKE_VERSION:=$(shell basename `bundle show rake`))
	@if [ "$(SYSTEM_RAKE_VERSION)" != "$(BUNDLE_RAKE_VERSION)" ]; then echo "rake version mismatch! System: $(SYSTEM_RAKE_VERSION) / Bundle: $(BUNDLE_RAKE_VERSION)"; exit 1; fi

test_rack:
	$(eval SYSTEM_RACK_VERSION:=$(shell basename `gem.ruby3.4 which -g rack | sed 's,/lib/rack.rb$$,,'`))
	$(eval BUNDLE_RACK_VERSION:=$(shell basename `bundle show rack`))
	@if [ "$(SYSTEM_RACK_VERSION)" != "$(BUNDLE_RACK_VERSION)" ]; then echo "rack version mismatch! System: $(SYSTEM_RACK_VERSION) / Bundle: $(BUNDLE_RACK_VERSION)"; exit 1; fi

test_base64_gem:
	$(eval RUBY_DEFAULT_BASE64_VERSION:=$(shell basename `gem.ruby3.4 which -g base64 | sed 's,/lib/base64.rb$$,,'`))
	$(eval BUNDLE_BASE64_VERSION:=$(shell basename `bundle show base64`))
	@if [ "$(RUBY_DEFAULT_BASE64_VERSION)" != "$(BUNDLE_BASE64_VERSION)" ]; then echo "base64 version mismatch! System Ruby Default: $(RUBY_DEFAULT_BASE64_VERSION) / Bundle: $(BUNDLE_BASE64_VERSION)"; exit 1; fi

clean:
	rm -rf ../../docs/api/html

.PHONY: test

include ../../Makefile.targets
