all: install

install: install_obsapisetup


install_obsapisetup:
	install -m 755 obsapisetup $(DESTDIR)/etc/init.d/obsapisetup
	install -m 755 setup-appliance.sh $(DESTDIR)$(OBS_BACKEND_DIR)/setup-appliance.sh

install_logrotate: system_dirs
	$(foreach config,$(LOGROTATE_CONFIGS),$(shell $(INSTALL) -m 755 $(config).logrotate $(DESTDIR)/etc/logrotate.d/$(config)) )

install_fillups: system_dirs
	$(INSTALL) -m 0644 sysconfig.obs-server $(DESTDIR)/var/adm/fillup-templates/

install_slp: system_dirs
	$(INSTALL) -m 644 obs.source_server.reg $(DESTDIR)/etc/slp.reg.d/
	$(INSTALL) -m 644 obs.repo_server.reg $(DESTDIR)/etc/slp.reg.d/

install_obs_bin: system_dirs
	$(foreach script,$(OBS_SCRIPTS),$(shell $(INSTALL) -m 755 $(script) $(DESTDIR)/usr/bin/$(script)) )

system_dirs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_BACKEND_DIR)
	$(INSTALL) -d -m 755 $(DESTDIR)/$(CONTRIB_DIR)
	$(INSTALL) -d -m 755 $(DESTDIR)/etc/init.d/
	$(INSTALL) -d -m 755 $(DESTDIR)/etc/logrotate.d/
	$(INSTALL) -d -m 755 $(DESTDIR)/etc/slp.reg.d/
	$(INSTALL) -d -m 755 $(DESTDIR)/usr/bin/
	$(INSTALL) -d -m 755 $(DESTDIR)/usr/sbin/
	$(INSTALL) -d -m 755 $(DESTDIR)/var/adm/fillup-templates


ta: test_all

test_all: test_unit test_system

t: test

test: test_unit

test_unit:
	prove t/*.t

ts: test_system
	
test_system:
	prove t/*.ts
