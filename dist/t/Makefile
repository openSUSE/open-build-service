.ONESHELL:

all:
	@echo "Targets: install test dbclean installclean"

install:
	zypper -vv -n --gpg-auto-import-keys in --force-resolution --no-recommends chromedriver xorg-x11-fonts libxml2-devel libxslt-devel ruby3.4-devel git-core make gcc
	git clone --single-branch --branch master --depth 1 https://github.com/openSUSE/open-build-service.git /tmp/open-build-service
	cd /tmp/open-build-service/dist/t
	bundle install

test:
	cd /tmp/open-build-service/dist/t
	bundle exec rspec --format documentation

dbclean:
	@echo "DISABLE_DATABASE_ENVIRONMENT_CHECK=$(DISABLE_DATABASE_ENVIRONMENT_CHECK) should be =1"
	@echo "SAFETY_ASSURED=$(SAFETY_ASSURED) should be =1"
	cd /srv/www/obs/api/ &&\
	bundle install &&\
	bundle exec rake db:drop db:create db:setup RAILS_ENV=production
	rm -rf /srv/obs/{trees/*,sources/[^:]*,projects/[^_]*,build/[^_]*,repos/*,*cache/*}

installclean:
	zypper -n rm -u chromedriver xorg-x11-fonts libxml2-devel libxslt-devel ruby2.7-devel
	rm -rf /tmp/open-build-service

