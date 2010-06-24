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

# ICHAIN_MODE can be one of  'on', 'off' or 'simulate'
ICHAIN_MODE = "off"

