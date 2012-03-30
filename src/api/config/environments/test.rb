# Settings specified here will take precedence over those in config/environment.rb

OBSApi::Application.configure do

# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils    = true

# Show full error reports and disable caching
# local requests don't trigger the global exception handler -> set to false
config.consider_all_requests_local = false
config.action_controller.perform_caching             = false

# Tell ActionMailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test
config.active_record.mass_assignment_sanitizer = :strict

config.cache_store = :memory_store

config.active_support.deprecation = :log

end

CONFIG['source_host'] = "localhost"
CONFIG['source_port'] = 3200
SOURCE_PROTOCOL = "http"

PROXY_AUTH_MODE=:off

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

RESPONSE_SCHEMA_VALIDATION = true

