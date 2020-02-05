include ../Makefile.include

LOGROTATE_CONFIGS     := obs-api obs-server obs-source_service
OBS_BIN_SCRIPTS       := obs_productconvert
OBS_SBIN_SCRIPTS      := obs_admin obs_serverstatus obsscheduler obsworker obsstoragesetup
SYSTEMD_TARGET_FILES  := obs-api-support
SYSTEMD_SERVICE_FILES := obs-clockwork obs-delayedjob-queue-project_log_rotate obs-delayedjob-queue-consistency_check obs-delayedjob-queue-default obs-delayedjob-queue-releasetracking obs-delayedjob-queue-issuetracking obs-delayedjob-queue-mailers obs-delayedjob-queue-staging obs-sphinx obsdeltastore obsdispatcher obsdodup obswarden obssrcserver obsrepserver obspublisher obssigner obsservice obsservicedispatch obsgetbinariesproxy obsclouduploadserver obsclouduploadworker obsscheduler obsworker obsstoragesetup obsapisetup obsnotifyforward obsredis
SYSTEMD_SERVICE_FILES_WITHOUT_LINK := obs-delayedjob-queue-quick@

FILLUPDIR             := /var/adm/fillup-templates

UNITDIR=/usr/lib/systemd/system/

install: install_obsapisetup install_apache install_project_update install_logrotate install_fillups install_slp install_obs_bin install_overview install_tests_appliance install_crontabs install_systemd_services

#install_overview

install_obsapisetup: system_dirs
	$(INSTALL) -m 755 setup-appliance.sh $(DESTDIR)$(OBS_BACKEND_PREFIX)/setup-appliance.sh
	sed -i \
	    -e 's|wwwrun\.www|$(APACHE_USER).$(APACHE_GROUP)|g' \
	    -e 's|/srv/www/obs/api|$(OBS_API_PREFIX)|g' \
	    -e 's|/srv/www/obs/overview|$(OBS_DOCUMENT_ROOT)/overview|g' \
	    -e 's|/srv/obs|$(OBS_BACKEND_DATA_DIR)|g' \
	    $(DESTDIR)$(OBS_BACKEND_PREFIX)/setup-appliance.sh

install_apache:
	$(INSTALL) -d -m 755  $(DESTDIR)$(APACHE_CONIFGDIR_VHOST)
	$(INSTALL) -m 644 $(APACHE_VHOST_CONF) $(DESTDIR)$(APACHE_CONIFGDIR_VHOST)/obs.conf
	sed -i \
	    -e 's|/srv/www/obs/api|$(OBS_API_PREFIX)|g' \
	    -e 's|/srv/www/obs/overview|$(OBS_DOCUMENT_ROOT)/overview|g' \
	    -e 's|/srv/obs|$(OBS_BACKEND_DATA_DIR)|g' \
	    $(DESTDIR)$(APACHE_CONIFGDIR_VHOST)/obs.conf

install_systemd_services: system_dirs
	$(foreach target,$(SYSTEMD_TARGET_FILES),$(shell $(INSTALL) -m 644 ./systemd/$(target).target $(DESTDIR)$(UNITDIR)$(target).target) )
	$(foreach service,$(SYSTEMD_SERVICE_FILES) $(SYSTEMD_SERVICE_FILES_WITHOUT_LINK),$(shell $(INSTALL) -m 644 ./systemd/$(service).service $(DESTDIR)$(UNITDIR)$(service).service) )
	sed -i \
	    -e 's|User = wwwrun|User = $(APACHE_USER)|g' \
	    -e 's|Group = www|Group = $(APACHE_GROUP)|g' \
	    -e 's|/srv/www/obs/api|$(OBS_API_PREFIX)|g' \
	    -e 's|/srv/obs|$(OBS_BACKEND_DATA_DIR)|g' \
	    $(DESTDIR)$(UNITDIR)/*.service

install_project_update: system_dirs
	$(INSTALL) -m 0755 obs_project_update $(DESTDIR)/usr/sbin/obs_project_update


install_logrotate: system_dirs
	$(foreach config,$(LOGROTATE_CONFIGS),$(shell $(INSTALL) -m 644 $(config).logrotate $(DESTDIR)/etc/logrotate.d/$(config)) )
	sed -i \
	    -e 's| wwwrun www| $(APACHE_USER) $(APACHE_GROUP)|g' \
	    -e 's|/srv/www/obs/api|$(OBS_API_PREFIX)|g' \
	    -e 's|/srv/obs|$(OBS_BACKEND_DATA_DIR)|g' \
	    -e 's|/srv/obs/log|$(OBS_BACKEND_LOG_DIR)|g' \
	    $(LOGROTATE_CONFIGS:%=$(DESTDIR)/etc/logrotate.d/%)

install_fillups: system_dirs
	$(INSTALL) -m 0644 sysconfig.obs-server $(DESTDIR)$(FILLUPDIR)
	sed -i \
	    -e 's|/srv/obs|$(OBS_BACKEND_DATA_DIR)|g' \
	    -e 's|/srv/obs/log|$(OBS_BACKEND_LOG_DIR)|g' \
	    -e 's|5352|$(OBS_SRCSERVER_PORT)|' \
	    -e 's|5252|$(OBS_REPOSERVER_PORT)|' \
	    -e 's|5152|$(OBS_SERVICESERVER_PORT)|' \
	    $(DESTDIR)$(FILLUPDIR)/sysconfig.obs-server

install_slp: system_dirs
	$(INSTALL) -m 644 obs.source_server.reg $(DESTDIR)/etc/slp.reg.d/
	$(INSTALL) -m 644 obs.repo_server.reg $(DESTDIR)/etc/slp.reg.d/
	sed -i \
	    -e 's|5352|$(OBS_SRCSERVER_PORT)|' \
	    -e 's|5252|$(OBS_REPOSERVER_PORT)|' \
	    $(DESTDIR)/etc/slp.reg.d/obs.source_server.reg \
	    $(DESTDIR)/etc/slp.reg.d/obs.repo_server.reg

install_obs_bin: system_dirs
	$(foreach script,$(OBS_BIN_SCRIPTS),$(shell $(INSTALL) -m 755 $(script) $(DESTDIR)/usr/bin/$(script)) )
	$(foreach script,$(OBS_SBIN_SCRIPTS),$(shell $(INSTALL) -m 755 $(script) $(DESTDIR)/usr/sbin/$(script)) )

install_crontabs:
	$(INSTALL) -m 644 cleanup_scm_cache.cron $(DESTDIR)/etc/cron.d/cleanup_scm_cache
	sed -i \
	    -e 's|/srv/www/obs/api|$(OBS_API_PREFIX)|g' \
	    -e 's|/srv/obs/service/log|$(OBS_BACKEND_SERVICE_LOG_DIR)|g' \
	    $(DESTDIR)/etc/cron.d/cleanup_scm_cache

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
	find $(DESTDIR)/usr/lib/obs/tests/appliance -type f -print | \
	  xargs sed -i -e 's|/srv/obs|$(OBS_BACKEND_DATA_DIR)|g'

test_unit:
	prove -v t/*.t

test_system:
	prove -v t/*.ts

test_appliance:
	prove -v t/*.ta

.PHONY: test_unit test_system
