# Settings specified here will take precedence over those in config/environment.rb

OBSApi::Application.configure do
  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Use memcache for cache/session storage
  if CONFIG['memcached_host']
    config.cache_store = :mem_cache_store, CONFIG['memcached_host']
    config.session_store = :mem_cache_store, CONFIG['memcached_host']
  else
    config.cache_store = :mem_cache_store
    config.session_store = :mem_cache_store
  end

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
  config.middleware.use(Rack::Deflater)

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Use lograge to show the logs in one line
  config.lograge.enabled = true
  config.lograge.custom_options = lambda do |event|
    exceptions = ['controller', 'action', 'format', 'id']
    {
      params: event.payload[:params].except(*exceptions),
      host:   event.payload[:headers].env['REMOTE_ADDR'],
      time:   event.time,
      user:   User.current.try(:login)
    }
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # memcache store for peek
  client = CONFIG['memcached_host'].nil? ? Dalli::Client.new : Dalli::Client.new(CONFIG['memcached_host'].to_s)
  config.peek.adapter = :memcache, {
    client: client
  }
end

# disabled on production for performance reasons
# CONFIG['response_schema_validation'] = true

# require 'memory_debugger'
# dumps the objects after every request
# config.middleware.insert(0, MemoryDebugger)

# require 'memory_dumper'
# dumps the full heap after next request on SIGURG
# config.middleware.insert(0, MemoryDumper)
