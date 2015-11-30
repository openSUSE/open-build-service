include ../../Makefile.include


OBS_API_LOGS := access.log backend_access.log delayed_job.log error.log lastevents.access.log
OBS_API_BUNDLER_OPTS=BUNDLE_WITHOUT=test:assets:development BUNDLE_FROZEN=1

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
	touch $(DESTDIR)$(OBS_API_PREFIX)/log/production.log
	touch $(DESTDIR)$(OBS_API_PREFIX)/config/production.sphinx.conf

docs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_APIDOCS_PREFIX)/api
	cp -a ../../docs/api/api $(DESTDIR)$(OBS_APIDOCS_PREFIX)
	cp -a ../../docs/api/html/* $(DESTDIR)$(OBS_APIDOCS_PREFIX)/api/
	ln -sf $(DESTDIR)$(OBS_APIDOCS_PREFIX)/api/ $(DESTDIR)$(OBS_API_PREFIX)/public/schema
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
	echo "" | sha256sum| cut -d\  -f 1 > config/secret.key
	bundle exec rake assets:precompile RAILS_ENV=production RAILS_GROUPS=assets
	rm -rf tmp/cache/sass tmp/cache/assets config/secret.key
	$(OBS_API_BUNDLER_OPTS) bundle config --local frozen 1
	$(OBS_API_BUNDLER_OPTS) bundle config --local without test:assets:development
	# reinstall
	$(INSTALL) config/database.yml.example config/database.yml
	: > log/production.log
	# TODO:
	# This makes no sense to me, but I took it as it was in spec file
	# Maybe this should be done in installed application or it is for testing
	#
	sed -i -e 's,^api_version.*,api_version = "%version",' config/initializers/02_apiversion.rb

test:
	./script/api_test_in_spec.sh
