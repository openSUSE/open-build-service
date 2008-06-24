# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new
config.log_level = :debug

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false

ICHAIN_MODE = :on

ICHAIN_HOST = "212.12.12.12"

SOURCE_HOST = "storage"
SOURCE_PORT = 5352

RPM_HOST = "storage"
RPM_PORT = 5252

APIDOCS_LOCATION = File.expand_path("#{RAILS_ROOT}/public/apidocs/html")+"/"
SCHEMA_LOCATION = File.expand_path("#{RAILS_ROOT}/public/schema")+"/"
