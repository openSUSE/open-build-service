include ../../Makefile.include

OBS_BACKEND_DATA_SUBDIRS := build events info jobs log projects repos run sources trees workers
OBS_BACKEND_DATA_DIR := /srv/obs

prepare_dirs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_BACKEND_PREFIX)
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_BACKEND_DATA_DIR)

bs_config:
	[ -f ./BSConfig.pm ] || cp ./BSConfig.pm.template ./BSConfig.pm
	

install: prepare_dirs install_data_dirs bs_config
	# prevent error while copy if there is an previous installation
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/build
	cp -a ./* $(DESTDIR)$(OBS_BACKEND_PREFIX)
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/build
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/Makefile
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/t
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/testdata
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/examples
	# just for check section, it is a %%ghost
	ln -sf /usr/lib/build $(DESTDIR)$(OBS_BACKEND_PREFIX)/build 

install_data_dirs: prepare_dirs
	$(foreach data_dir,$(OBS_BACKEND_DATA_SUBDIRS), \
		$(shell $(INSTALL) -d -m 755 $(DESTDIR)$(OBS_BACKEND_DATA_DIR)/$(data_dir) ) \
	)


test_unit: bs_config
	rm -rf t/tmp/*
	LANG=C prove -Ibuild -I. -v t/*.t

cover: bs_config clean_cover
	rm -rf t/tmp/*
	PERL5OPT=-MDevel::Cover LANG=C prove -Ibuild -I. -v t/*.t
	cover -ignore_re '^((build|XML|t)/|/usr/bin/prove$$)' -outputdir /srv/www/htdocs

clean_cover:
	rm -rf cover_db/

.PHONY: test_unit cover
