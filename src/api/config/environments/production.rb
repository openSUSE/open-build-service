# Settings specified here will take precedence over those in config/environment.rb

OBSApi::Application.configure do
  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Use a different logger for distributed setups
  # config.logger        = SyslogLogger.new
  config.log_level = :info

  config.eager_load = true

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host                  = "http://assets.example.com"

  # see http://guides.rubyonrails.org/action_mailer_basics.html#example-action-mailer-configuration
  config.action_mailer.delivery_method = :sendmail
  config.action_mailer.perform_caching = false

  config.active_support.deprecation = :log

   # Enable serving of images, stylesheets, and javascripts from an asset server
   # config.action_controller.asset_host                  = "http://assets.example.com"

  config.cache_store = :dalli_store, '127.0.0.1:11211', {namespace: 'obs-api', compress: true, expires_in: 1.day }

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.public_file_server.enabled = false

  # Compress JavaScripts and CSS
  config.assets.compress = true
  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # compress our HTML
  config.middleware.use Rack::Deflater

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
end

# disabled on production for performance reasons
# CONFIG['response_schema_validation'] = true

# require 'memory_debugger'
# dumps the objects after every request
# config.middleware.insert(0, MemoryDebugger)

# require 'memory_dumper'
# dumps the full heap after next request on SIGURG
# config.middleware.insert(0, MemoryDumper)
