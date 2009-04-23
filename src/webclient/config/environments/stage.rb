# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = false

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new

config.log_level        = :debug


# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

# Enable serving of images, stylesheets, and javascripts from an asset server
#config.action_controller.asset_host                  = "https://build.opensuse.org/stage"

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false

FRONTEND_HOST = "api-internal.opensuse.org"
FRONTEND_PORT = 80
FRONTEND_PROTOCOL = 'http'

BUGZILLA_HOST = "http://bugzilla.novell.com"
# ICHAIN_MODE can be one of  'on', 'off' or 'simulate'
ICHAIN_MODE = "on"

BASE_NAMESPACE = nil

### not nescessary any more as of 2006.12.01:
### ICHAIN_HOST = "212.12.12.12"

ActionController::AbstractRequest.relative_url_root = "/stage"
