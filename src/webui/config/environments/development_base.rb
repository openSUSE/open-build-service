# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = false

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false

config.log_level = :debug

FRONTEND_HOST = "api.opensuse.org"
FRONTEND_PORT = 443
FRONTEND_PROTOCOL = 'https'

# use this when the users see the api at another url (for rpm-, file-downloads)
#EXTERNAL_FRONTEND_HOST = "api.opensuse.org"

# If ICHAIN_HOST is set to "simulate", iChain is simulated in the
# way that the ichain header entry is set to the value specified
# in the ICHAIN_TEST_USER variable here below.
# ATTENTION: If you set an IP address here the frontend takes the
# user name that is coming as headervalue X-username as a valid
# user and does not further authentication. So take care...
# ATTENTION 2: The ICHAIN_* entries must correspond with the entries
# in the frontend otherwise funny things happen.

# ICHAIN_MODE can be one of  'on', 'off' or 'simulate'
ICHAIN_HOST = "https://build.opensuse.org"
ICHAIN_MODE = "off"
#ICHAIN_TEST_USER = "adrianSuSE"
#ICHAIN_TEST_EMAIL = "foo@bar.com
