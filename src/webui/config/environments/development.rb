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

FRONTEND_HOST = "api.opensuse.org"
FRONTEND_PORT = 443
FRONTEND_PROTOCOL = 'https'
FRONTEND_LDAP_MODE = :off

# use this when the users see the api at another url (for rpm-, file-downloads)
#EXTERNAL_FRONTEND_PROTOCOL = "https"
#EXTERNAL_FRONTEND_HOST = "api.opensuse.org"
#EXTERNAL_FRONTEND_PORT = 443

# If PROXY_AUTH_MODE is set to "simulate", iChain is simulated in the
# way that the ichain header entry is set to the value specified
# in the PROXY_AUTH_TEST_USER variable here below.
# ATTENTION: If you set an IP address here the frontend takes the
# user name that is coming as headervalue X-username as a valid
# user and does not further authentication. So take care...
# ATTENTION 2: The PROXY_AUTH_* entries must correspond with the entries
# in the frontend otherwise funny things happen.

# PROXY_AUTH_MODE can be one of  'on', 'off' or 'simulate'
PROXY_AUTH_MODE = :off
#PROXY_AUTH_HOST = "https://build.opensuse.org"
#PROXY_AUTH_REGISTER_PAGE = "https://en.opensuse.org/ICSLogin/?%22http://en.opensuse.org/index.php%22"
#PROXY_AUTH_LOGIN_PAGE = "https://build.opensuse.org/ICSLogin"
#PROXY_AUTH_LOGOUT_PAGE = "/cmd/ICSLogout"
#EXTERNAL_WEBUI_PROTOCOL = "https"
#EXTERNAL_WEBUI_HOST = "build.opensuse.org"
#PROXY_AUTH_TEST_USER = "adrianSuSE"
#PROXY_AUTH_TEST_EMAIL = "foo@bar.com"

# Check for custom development environment that takes precedence:
require 'socket'
local_path = "#{Rails.root}/config/environments/development.#{Socket.gethostname}.rb"
begin
  eval File.read(local_path)
  STDERR.puts "Using local development environment #{local_path}"
rescue Object => e
  STDERR.puts "No local development environment found: #{e}"
end
