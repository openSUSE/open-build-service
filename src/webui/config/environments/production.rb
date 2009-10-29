# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new

config.log_level = :info

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false

FRONTEND_HOST = "api.opensuse.org"
FRONTEND_PORT = 443
FRONTEND_PROTOCOL = 'https'

# use this when the users see the api at another url (for rpm-, file-downloads)
#EXTERNAL_FRONTEND_HOST = "api.opensuse.org"

BUGZILLA_HOST = "https://bugzilla.novell.com"
DOWNLOAD_URL = "http://download.opensuse.org/repositories"

# ICHAIN_MODE can be one of  'on', 'off' or 'simulate'
ICHAIN_MODE = "off"

BASE_NAMESPACE = nil
