# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new

config.log_level        = :debug


# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

config.cache_store = :compressed_mem_cache_store, 'localhost:11211', {:namespace => 'obs-webclient-stage'}

config.action_controller.session = {
    :prefix => "ruby_webclient_stage_session",
    :session_key => "opensuse_webclient_stage_session",
    :secret => "iofupo3i4u6097p09gfsnaf7g8974lh1j3khdlsufdzg9p889234"
}

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false

FRONTEND_HOST = "api.opensuse.org"
EXTERNAL_FRONTEND_HOST = "api.opensuse.org"
FRONTEND_PORT = 80
FRONTEND_PROTOCOL = 'http'

# ICHAIN_MODE can be one of  'on', 'off' or 'simulate'
ICHAIN_MODE = "on"
ICHAIN_HOST = "https://build.opensuse.org"
