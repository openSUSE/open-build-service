# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = false

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new
config.log_level = :debug

# Full error reports are disabled and caching is turned on
config.consider_all_requests_local = false
config.action_controller.perform_caching = true

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false

ActionController::AbstractRequest.relative_url_root = '/stage'

CONFIG['response_schema_validation'] = true
