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
  config.cache_store = :mem_cache_store, 'localhost:11211', {namespace: 'obs-webclient', compress: true}

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

CONFIG['frontend_host'] = "api.opensuse.org"
CONFIG['frontend_port'] = 443
CONFIG['frontend_protocol'] = 'https'
CONFIG['frontend_ldap_mode'] = :off

# Enable the interface to change user's password, it can be one of 'on', 'off'
CONFIG['change_passwd'] = "on"

##
## The following is needed when the authentification is done by a proxy server in front
## of OBS. The external api name is usually different to the local one in this case.
##
CONFIG['proxy_auth_host'] = "https://build.opensuse.org"
CONFIG['proxy_auth_login_page'] = "https://build.opensuse.org/ICSLogin"
CONFIG['proxy_auth_logout_page'] = "/cmd/ICSLogout"
# CONFIG['external_frontend_host'] = "api.opensuse.org"
# CONFIG['external_frontend_port'] = 443
# CONFIG['external_frontend_protocol'] = 'https'
# CONFIG['proxy_auth_mode'] can be one of  'on', 'off' or 'simulate'
CONFIG['proxy_auth_mode'] = :off
#CONFIG['proxy_auth_host'] = "https://build.opensuse.org"
#CONFIG['proxy_auth_register_page'] = "https://en.opensuse.org/ICSLogin"
#CONFIG['proxy_auth_login_page'] = "https://build.opensuse.org/ICSLogin"
#CONFIG['proxy_auth_logout_page'] = "/cmd/ICSLogout"
#CONFIG['external_webui_protocol'] = "https"
#CONFIG['external_webui_host'] = "build.opensuse.org"
#CONFIG['proxy_auth_test_user'] = "adrianSuSE"
#CONFIG['proxy_auth_test_email'] = "foo@bar.com"

