OBSWebUI::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = false

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store
  config.cache_store = :compressed_mem_cache_store, 'localhost:11211', {:namespace => 'obs-webclient'}

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5
end

FRONTEND_HOST = "api.opensuse.org"
FRONTEND_PORT = 443
FRONTEND_PROTOCOL = 'https'
FRONTEND_LDAP_MODE = :off

# Enable the interface to change user's password, it can be one of 'on', 'off'
CHANGE_PASSWD = "on"

##
## The following is needed when the authentification is done by a proxy server in front
## of OBS. The external api name is usually different to the local one in this case.
##
PROXY_AUTH_HOST = "https://build.opensuse.org"
PROXY_AUTH_LOGIN_PAGE = "https://build.opensuse.org/ICSLogin"
PROXY_AUTH_LOGOUT_PAGE = "/cmd/ICSLogout"
# EXTERNAL_FRONTEND_HOST = "api.opensuse.org"
# EXTERNAL_FRONTEND_PORT = 443
# EXTERNAL_FRONTEND_PROTOCOL = 'https'
# PROXY_AUTH_MODE can be one of  'on', 'off' or 'simulate'
PROXY_AUTH_MODE = :off
#PROXY_AUTH_HOST = "https://build.opensuse.org"
#PROXY_AUTH_REGISTER_PAGE = "https://en.opensuse.org/ICSLogin"
#PROXY_AUTH_LOGIN_PAGE = "https://build.opensuse.org/ICSLogin"
#PROXY_AUTH_LOGOUT_PAGE = "/cmd/ICSLogout"
#EXTERNAL_WEBUI_PROTOCOL = "https"
#EXTERNAL_WEBUI_HOST = "build.opensuse.org"
#PROXY_AUTH_TEST_USER = "adrianSuSE"
#PROXY_AUTH_TEST_EMAIL = "foo@bar.com"

