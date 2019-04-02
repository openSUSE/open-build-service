include ../Makefile.include

LOGROTATE_CONFIGS     := obs-api obs-server obs-source_service
OBS_BIN_SCRIPTS       := obs_productconvert
OBS_SBIN_SCRIPTS      := obs_admin obs_serverstatus obsscheduler obsworker obsstoragesetup
SYSTEMD_TARGET_FILES  := obs-api-support
SYSTEMD_SERVICE_FILES := obs-clockwork obs-delayedjob-queue-project_log_rotate obs-delayedjob-queue-consistency_check obs-delayedjob-queue-default obs-delayedjob-queue-releasetracking obs-delayedjob-queue-issuetracking obs-delayedjob-queue-mailers obs-delayedjob-queue-staging obs-sphinx obsdeltastore obsdispatcher obsdodup obswarden obssrcserver obsrepserver obspublisher obssigner obsservice obsservicedispatch obsgetbinariesproxy obsclouduploadserver obsclouduploadworker obsscheduler obsworker obsstoragesetup obsapisetup
SYSTEMD_SERVICE_FILES_WITHOUT_LINK := obs-delayedjob-queue-quick@

FILLUPDIR             := /var/adm/fillup-templates

UNITDIR=/usr/lib/systemd/system/

install: install_obsapisetup install_apache install_project_update install_logrotate install_fillups install_slp install_obs_bin install_overview install_tests_appliance install_crontabs install_systemd_services

#install_overview

install_obsapisetup: system_dirs
	$(INSTALL) -m 755 setup-appliance.sh $(DESTDIR)$(OBS_BACKEND_PREFIX)/setup-appliance.sh

install_apache:
	$(INSTALL) -d -m 755  $(DESTDIR)$(APACHE_CONIFGDIR_VHOST)
	$(INSTALL) -m 644 $(APACHE_VHOST_CONF) $(DESTDIR)$(APACHE_CONIFGDIR_VHOST)/obs.conf

install_systemd_services: system_dirs
	$(foreach target,$(SYSTEMD_TARGET_FILES),$(shell $(INSTALL) -m 644 ./systemd/$(target).target $(DESTDIR)$(UNITDIR)$(target).target) )
	$(foreach service,$(SYSTEMD_SERVICE_FILES) $(SYSTEMD_SERVICE_FILES_WITHOUT_LINK),$(shell $(INSTALL) -m 644 ./systemd/$(service).service $(DESTDIR)$(UNITDIR)$(service).service) )
	$(foreach service,$(SYSTEMD_TARGET_FILES) $(SYSTEMD_SERVICE_FILES),$(shell ln -sf /usr/sbin/service $(DESTDIR)/usr/sbin/rc$(service) ) )

install_project_update: system_dirs
	$(INSTALL) -m 0755 obs_project_update $(DESTDIR)/usr/sbin/obs_project_update


install_logrotate: system_dirs
	$(foreach config,$(LOGROTATE_CONFIGS),$(shell $(INSTALL) -m 644 $(config).logrotate $(DESTDIR)/etc/logrotate.d/$(config)) )

install_fillups: system_dirs
	$(INSTALL) -m 0644 sysconfig.obs-server $(DESTDIR)$(FILLUPDIR)

install_slp: system_dirs
	$(INSTALL) -m 644 obs.source_server.reg $(DESTDIR)/etc/slp.reg.d/
	$(INSTALL) -m 644 obs.repo_server.reg $(DESTDIR)/etc/slp.reg.d/

install_obs_bin: system_dirs
	$(foreach script,$(OBS_BIN_SCRIPTS),$(shell $(INSTALL) -m 755 $(script) $(DESTDIR)/usr/bin/$(script)) )
	$(foreach script,$(OBS_SBIN_SCRIPTS),$(shell $(INSTALL) -m 755 $(script) $(DESTDIR)/usr/sbin/$(script)) )

install_crontabs:
	$(INSTALL) -m 644 cleanup_scm_cache.cron $(DESTDIR)/etc/cron.d/cleanup_scm_cache

system_dirs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_BACKEND_PREFIX)
	$(INSTALL) -d -m 755 $(DESTDIR)/etc/logrotate.d/
	$(INSTALL) -d -m 755 $(DESTDIR)/etc/slp.reg.d/
	$(INSTALL) -d -m 755 $(DESTDIR)/etc/cron.d/
	$(INSTALL) -d -m 755 $(DESTDIR)/usr/bin/
	$(INSTALL) -d -m 755 $(DESTDIR)/usr/sbin/
	$(INSTALL) -d -m 755 $(DESTDIR)$(FILLUPDIR)
	$(INSTALL) -d -m 755 $(DESTDIR)/usr/lib/obs/tests/appliance
	$(INSTALL) -d -m 755 $(DESTDIR)$(UNITDIR)

install_overview:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_DOCUMENT_ROOT)/overview
	$(INSTALL) -m 644 overview.html.TEMPLATE $(DESTDIR)$(OBS_DOCUMENT_ROOT)/overview

install_tests_appliance:
	cp -r ./t/*	$(DESTDIR)/usr/lib/obs/tests/appliance/

test_unit:
	prove -v t/*.t

test_system:
	prove -v t/*.ts

test_appliance:
	prove -v t/*.ta

.PHONY: test_unit test_system
