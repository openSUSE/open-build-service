# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = false

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new

config.log_level        = :info


# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false

FRONTEND_HOST = "127.0.42.2"
FRONTEND_PORT = 80
FRONTEND_PROTOCOL = 'http'

EXTERNAL_FRONTEND_HOST = "127.0.42.2"
EXTERNAL_FRONTEND_PORT = 80


BUGZILLA_HOST = "http://my.bugzilla/"
DOWNLOAD_URL = "http://127.0.42.3/"

# ICHAIN_MODE can be one of  'on', 'off' or 'simulate'
ICHAIN_MODE = "off"

BASE_NAMESPACE = "openSUSE.org"

