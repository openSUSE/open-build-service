include ../../Makefile.include


OBS_API_LOGS := access.log backend_access.log delayed_job.log error.log lastevents.access.log

all:

install: prepare_dirs prepare_rake docs config log_files build

prepare_dirs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_API_PREFIX)
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_API_PREFIX)/log
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

docs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_APIDOCS_PREFIX)/api
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_APIDOCS_PREFIX)/api/html
	cp -av ../../docs/api/api $(DESTDIR)$(OBS_APIDOCS_PREFIX)
	cp -av ../../docs/api/html/* $(DESTDIR)$(OBS_APIDOCS_PREFIX)/api/html/
	ln -sf $(OBS_APIDOCS_PREFIX)/api/ $(DESTDIR)$(OBS_API_PREFIX)/public/schema
	echo 'CONFIG["apidocs_location"] ||= File.expand_path("../docs/api/html/")' >> $(DESTDIR)$(OBS_API_PREFIX)/config/environment.rb
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
	echo "" | sha256sum| cut -d\  -f 1 > $(DESTDIR)/srv/www/obs/api/config/secret.key
	cd $(DESTDIR)/srv/www/obs/api ;\
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
clean:
	rm -rf ../../docs/api/html

.PHONY: test
