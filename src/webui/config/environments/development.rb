OBSWebUI::Application.configure do
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

  config.log_level = :debug
end

CONFIG['frontend_host'] = "api.opensuse.org"
CONFIG['frontend_port'] = 443
CONFIG['frontend_protocol'] = 'https'
CONFIG['frontend_ldap_mode'] = :off

# use this when the users see the api at another url (for rpm-, file-downloads)
#CONFIG['external_frontend_protocol'] = "https"
#CONFIG['external_frontend_host'] = "api.opensuse.org"
#CONFIG['external_frontend_port'] = 443

# If CONFIG['proxy_auth_mode'] is set to "simulate", iChain is simulated in the
# way that the ichain header entry is set to the value specified
# in the CONFIG['proxy_auth_test_user'] variable here below.
# ATTENTION: If you set an IP address here the frontend takes the
# user name that is coming as headervalue X-username as a valid
# user and does not further authentication. So take care...
# ATTENTION 2: The PROXY_AUTH_* entries must correspond with the entries
# in the frontend otherwise funny things happen.

# CONFIG['proxy_auth_mode'] can be one of  'on', 'off' or 'simulate'
CONFIG['proxy_auth_mode'] = :off
#CONFIG['proxy_auth_host'] = "https://build.opensuse.org"
#CONFIG['proxy_auth_register_page'] = "https://en.opensuse.org/ICSLogin/?%22http://en.opensuse.org/index.php%22"
#CONFIG['proxy_auth_login_page'] = "https://build.opensuse.org/ICSLogin"
#CONFIG['proxy_auth_logout_page'] = "/cmd/ICSLogout"
#CONFIG['external_webui_protocol'] = "https"
#CONFIG['external_webui_host'] = "build.opensuse.org"
#CONFIG['proxy_auth_test_user'] = "adrianSuSE"
#CONFIG['proxy_auth_test_email'] = "foo@bar.com"

# Check for custom development environment that takes precedence:
require 'socket'
fname = "#{Rails.root}/config/environments/development.#{Socket.gethostname}.rb"
if File.exists? fname
  STDERR.puts "Using local development environment #{fname}"
  eval File.read(fname)  
else
  STDERR.puts "Custom development.#{Socket.gethostname}.rb not found - using defaults"
end
