# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
config.action_view.cache_template_loading            = true

# See everything in the log (default is :info)
config.log_level = :debug

# Use a different logger for distributed setups
# config.logger = SyslogLogger.new

# Use a different cache store in production
# config.cache_store = :mem_cache_store
config.cache_store = :compressed_mem_cache_store, 'localhost:11211', {:namespace => 'obs-webclient'}


# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false

# Enable threaded mode
# config.threadsafe!

config.action_controller.session = {
    :prefix => "ruby_webclient_session",
    :session_key => "buildservice_webclient_session",
    :secret => "iofupo3i4u6097p09gfsnaf7g8974lh1j3khdlsufdzg9p877234"
}

FRONTEND_HOST = "api.opensuse.org"
FRONTEND_PORT = 443
FRONTEND_PROTOCOL = 'https'

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

