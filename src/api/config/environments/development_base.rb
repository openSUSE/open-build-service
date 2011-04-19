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
#SOURCE_PORT = 6362 #test backend
SOURCE_HOST = "localhost"
SOURCE_PORT = 5352
SOURCE_PROTOCOL = "http"

# ATTENTION: If PROXY_AUTH_MODE is :on, the frontend takes the user
# name that is coming as headervalue X-username as a 
# valid user does no further authentication. So take care...
# PROXY_AUTH_MODE can be :off, :on or :simulate
PROXY_AUTH_TEST_USER = "test"
PROXY_AUTH_MODE = :off

LDAP_MODE = :off
# LDAP Servers separated by ':'.
# OVERRIDE with your company's ldap servers. Servers are picked randomly for
# each connection to distribute load.
LDAP_SERVERS = "ldap1.mycompany.com:ldap2.mycompany.com"
# OVERRIDE with your company's ldap search base for the users who will use OBS
LDAP_SEARCH_BASE = "OU=Organizational Unit,DC=Domain Component"
# Sam Account Name is the login name for LDAP 
LDAP_SEARCH_ATTR = "sAMAccountName"
# Max number of times to attempt to contact the LDAP servers
MAX_LDAP_ATTEMPTS = 10

EXTENDED_BACKEND_LOG = true
DOWNLOAD_URL='http://download.opensuse.org/repositories'
YMP_URL='http://software.opensuse.org/ymp'

RESPONSE_SCHEMA_VALIDATION = true
