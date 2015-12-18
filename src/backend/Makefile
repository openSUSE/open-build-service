include ../../Makefile.include

OBS_BACKEND_DATA_SUBDIRS := build events info jobs log projects repos run sources trees workers
OBS_BACKEND_DATA_DIR := /srv/obs

prepare_dirs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_BACKEND_PREFIX)
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_BACKEND_DATA_DIR)

install: prepare_dirs install_data_dirs
	# prevent error while copy if there is an previous installation
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/build
	cp -a ./* $(DESTDIR)$(OBS_BACKEND_PREFIX)
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/Makefile
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/t
	[ -f $(DESTDIR)$(OBS_BACKEND_PREFIX)/BSConfig.pm ] || cp ./BSConfig.pm.template $(DESTDIR)$(OBS_BACKEND_PREFIX)/BSConfig.pm
	rm -rf $(DESTDIR)$(OBS_BACKEND_PREFIX)/testdata
	# just for check section, it is a %%ghost
	ln -sf /usr/lib/build $(DESTDIR)$(OBS_BACKEND_PREFIX)/build 

install_data_dirs: prepare_dirs
	$(foreach data_dir,$(OBS_BACKEND_DATA_SUBDIRS), \
		$(shell $(INSTALL) -d -m 755 $(DESTDIR)$(OBS_BACKEND_DATA_DIR)/$(data_dir) ) \
	)


test_unit:
        LANG=C prove -Ibuild t/*.t
