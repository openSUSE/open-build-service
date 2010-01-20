# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes     = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils        = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = false

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false

# Enable debug logging by default
config.log_level = :debug

#SOURCE_HOST = "buildservice.suse.de"
SOURCE_HOST = "localhost"

#SOURCE_PORT = 5352
SOURCE_PORT = 6362 #test backend

# ATTENTION: If ICHAIN_MODE is :on, the frontend takes the user
# name that is coming as headervalue X-username as a 
# valid user does no further authentication. So take care...
# ICHAIN_MODE can be :off, :on or :simulate
ICHAIN_TEST_USER = "test"
ICHAIN_MODE = :off

APIDOCS_LOCATION = File.expand_path("#{RAILS_ROOT}/../../docs/api/html/")
SCHEMA_LOCATION = File.expand_path("#{RAILS_ROOT}/../../docs/api/api")+"/"

EXTENDED_BACKEND_LOG = true
DOWNLOAD_URL='http://download.opensuse.org/repositories'
YMP_URL='http://software.opensuse.org/ymp'
