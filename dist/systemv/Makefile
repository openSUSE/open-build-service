include ../../Makefile.include

INIT_SCRIPTS 			:= obssrcserver obsrepserver obsscheduler obsworker obspublisher obsdispatcher obssigner obswarden obsapidelayed obsapisetup obsstoragesetup obsservice obsdodup obsdeltastore obsservicedispatch

install: install_systemv_scripts

install_systemv_scripts: system_dirs
	$(foreach script,$(INIT_SCRIPTS),$(shell $(INSTALL) -m 755 $(script) $(DESTDIR)/etc/init.d/$(script)) )
	$(foreach script,$(INIT_SCRIPTS),$(shell ln -sf /etc/init.d/$(script) $(DESTDIR)/usr/sbin/rc$(script)) )

system_dirs:
	$(INSTALL) -d -m 755 $(DESTDIR)$(OBS_BACKEND_PREFIX)
	$(INSTALL) -d -m 755 $(DESTDIR)/etc/init.d/

