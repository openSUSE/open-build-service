# Settings specified here will take precedence over those in config/environment.rb

OBSApi::Application.configure do

  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  config.active_record.auto_explain_threshold_in_seconds = 0.5

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true

  # Enable debug logging by default
  config.log_level = :debug

end

CONFIG['source_host'] = "localhost"
CONFIG['source_port'] = 5352
SOURCE_PROTOCOL = "http"

# ATTENTION: If CONFIG['proxy_auth_mode'] is :on, the frontend takes the user
# name that is coming as headervalue X-username as a 
# valid user does no further authentication. So take care...
# CONFIG['proxy_auth_mode'] can be :off, :on or :simulate
CONFIG['proxy_auth_test_user'] = "test"
CONFIG['proxy_auth_mode'] = :off

CONFIG['ldap_mode'] = :off
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

CONFIG['extended_backend_log'] = true
CONFIG['download_url']='http://download.opensuse.org/repositories'
YMP_URL='http://software.opensuse.org/ymp'

RESPONSE_SCHEMA_VALIDATION = true

require 'socket'
fname = "#{Rails.root}/config/environments/development.#{Socket.gethostname}.rb"
if File.exists? fname
  STDERR.puts "Using local environment #{fname}"
  eval File.read(fname)  
else
  STDERR.puts "Custom development.#{Socket.gethostname}.rb not found - using defaults"
end

