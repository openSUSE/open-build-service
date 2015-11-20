CONTRIB_DIR=$(DESTDIR)/usr/share/doc/packages/obs-api/contrib

all: install

install: install_obsapisetup

install_obsapisetup:
	install -m 755 ./obsapisetup $(DESTDIR)/etc/init.d/obsapisetup
	[ -d $(CONTRIB_DIR) ] || mkdir -p $(CONTRIB_DIR)
	install -m 755 ./setup-appliance.sh $(CONTRIB_DIR)/setup-appliance.sh

ta: test_all

test_all: test_unit test_system

t: test

test: test_unit

test_unit:
	prove t/*.t

ts: test_system
	
test_system:
	prove t/*.ts
