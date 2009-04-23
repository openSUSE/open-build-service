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

SOURCE_HOST = "buildservice.suse.de"
#SOURCE_HOST = "localhost"

SOURCE_PORT = 5352
#SOURCE_PORT = 6362 #test backend

# set the iChain host to something not nil to use iChain. Note
# that the IP is not used atm but that might change.
# If ICHAIN_HOST is set to "simulate", iChain is simulated in the
# way that the ichain header entry is set to the value specified
# in the ICHAIN_TEST_USER variable here below.
ICHAIN_TEST_USER = "test"

# This will replace the old constant ICHAIN_HOST.
#  ATTENTION: If it's :on, the frontend takes the user
# name that is coming as headervalue X-username as a 
# valid user does no further authentication. So take care...
#  ATTENTION: The ICHAIN_* entries must correspond with the
# entries in the webclient otherwise funny things happen.
# ICHAIN_MODE can be :off, :on or :simulate
#
ICHAIN_MODE = :off

APIDOCS_LOCATION = "../../docs/api/html/"
SCHEMA_LOCATION = File.expand_path("#{RAILS_ROOT}/../../docs/api/frontend")+"/"

EXTENDED_BACKEND_LOG = true
