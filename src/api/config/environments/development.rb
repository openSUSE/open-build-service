# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes     = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils        = true

# Enable the breakpoint server that script/breakpointer connects to
config.breakpoint_server = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = false

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false

BREAKPOINT_SERVER_PORT=42532

SOURCE_HOST = "buildservice.suse.de"
SOURCE_PORT = 5352

RPM_HOST = "buildservice.suse.de"
RPM_PORT = 5252

#
# ICHAIN_HOST is the IP address of the iChain proxy that is taking
# care of the authentication.
# ATTENTION: If you set an IP address here the frontend takes the
# user name that is coming as headervalue X-username as a valid
# user and does not further authentication. So take care...
# ICHAIN_HOST = "212.22.211.221"

#SOURCE_HOST = "localhost"
#SOURCE_PORT = 5352

#RPM_HOST = "localhost"
#RPM_PORT = 5252

APIDOCS_LOCATION = "../../docs/architecture/html/"
SCHEMA_LOCATION = File.expand_path("#{RAILS_ROOT}/../../docs/architecture")+"/"

EXTENDED_BACKEND_LOG = true
