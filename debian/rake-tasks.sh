#!/bin/sh -e

reload_apache()
{
    if apache2ctl configtest 2>/dev/null; then
	if [ -x /usr/sbin/invoke-rc.d ]; then
	    invoke-rc.d apache2 $1 3>/dev/null || true && \
	    echo "Apache restarted."
	else
	    /etc/init.d/apache2 $1 3>/dev/null || true && \
	    echo "Apache restarted."
	fi
    else
	echo "Your Apache 2 configuration is broken, so we're not restarting it for you."
    fi
}

case "$1" in
	setup)

	# Refine permissions for rails app.
	chown www-data:root /usr/share/obs/api/config/environment.rb
	chown -R www-data:www-data /var/log/obs/
	chown -R www-data:www-data /var/cache/obs/tmp/
	chown -R www-data:www-data /usr/share/obs/api/db
	chown -R www-data:www-data /usr/share/obs/api/public
	chown www-data:www-data /etc/obs/api/config/production.sphinx.conf
	chmod 664 /var/log/obs/*.log
	chown obsapi:obsapi /etc/obs/api/config/database.yml
	chmod 440 /etc/obs/api/config/database.yml
	chown obsapi:obsapi /var/log/obs/backend_access.log
	chown obsapi:obsapi /var/log/obs/production.log

	# Generate Gemfile.lock file.
	cd /usr/share/obs/api
	rm -f Gemfile.lock
	rm -f .bundle/config
	bundle --local --quiet

	# Setup database
	RAILS_ENV=production bundle exec rake db:create >> log/db_setup.log
	RAILS_ENV=production bundle exec rake db:setup >> log/db_setup.log

	export BUNDLE_WITHOUT=test:assets:development
	export BUNDLE_FROZEN=1
	bundle config --local frozen 1
	bundle config --local without test:assets:development

	API_ROOT=/usr/share/obs/api

	run_in_api () {
	export RAILS_ENV="production"
	echo "Run in api."
	chroot --userspec=www-data:www-data / /bin/bash -c "cd $API_ROOT && bundle exec $*"
	}

	run_in_api rake assets:precompile RAILS_ENV=production RAILS_GROUPS=assets
	run_in_api rake ts:index

	# Start up obsapidelayed
	if [ -x /usr/sbin/invoke-rc.d ]; then
            invoke-rc.d obsapidelayed restart 3>/dev/null || true && \
	    echo "obsapidelayed restarted."
        else
            /etc/init.d/obsapidelayed restart 3>/dev/null || true && \
	    echo "obsapidelayed restarted."
        fi


	# Test whether a2enmod is available (and thus also apache2ctl).
	if [ -x /usr/sbin/a2enmod ]; then
		# Enable the Apache2 modules if not already enabled
		a2enmod ssl     > /dev/null || true
		a2enmod rewrite > /dev/null || true
		a2enmod proxy   > /dev/null || true
		a2enmod proxy_http      > /dev/null || true
		a2enmod xforward        > /dev/null || true
		a2enmod headers > /dev/null || true
		a2enmod expires > /dev/null || true
		a2dissite 000-default   > /dev/null || true
		a2ensite obs.conf	> /dev/null || true
	fi

	# Restart Apache to really enable the module and load obs.conf
	reload_apache restart
	;;
    migrate)
	# Migrade the database
	cd /usr/share/obs/api
	RAILS_ENV=production bundle exec rake db:migrate >> log/db_migrate.log

	# Restart Apache to really enable the module and load obs.conf
	reload_apache restart
	;;
    *)
	echo "Usage: $0 {setup|migrate}"
	exit 1
    ;;
esac
