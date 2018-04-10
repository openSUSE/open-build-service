# frozen_string_literal: true

# Settings specified here will take precedence over those in config/environment.rb

OBSApi::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # see http://guides.rubyonrails.org/action_mailer_basics.html#example-action-mailer-configuration
  config.action_mailer.delivery_method = :smtp
  # we deliver to mailcatcher https://github.com/sj26/mailcatcher
  config.action_mailer.smtp_settings = { address: '127.0.0.1', port: '1025' }
  config.action_mailer.raise_delivery_errors = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = true

  # Use memcache for cache/session storage
  if CONFIG['memcached_host']
    config.cache_store = :mem_cache_store, CONFIG['memcached_host']
    config.session_store = :mem_cache_store, CONFIG['memcached_host']
  else
    config.cache_store = :mem_cache_store
    config.session_store = :mem_cache_store
  end

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.logger = nil
  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true
  # turn of the asset pipeline log. Previously done by quiet_assets gem.
  config.assets.quiet = true

  # Enable debug logging by default
  config.log_level = :debug

  # rubocop:disable Metrics/LineLength
  config.secret_key_base = '92b2ed725cb4d68cc5fbf86d6ba204f1dec4172086ee7eac8f083fb62ef34057f1b770e0722ade7b298837be7399c6152938627e7d15aca5fcda7a4faef91fc7'
  # rubocop:enable Metrics/LineLength

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # memcache store for peek
  client = CONFIG['memcached_host'].nil? ? Dalli::Client.new : Dalli::Client.new(CONFIG['memcached_host'].to_s)
  config.peek.adapter = :memcache, {
    client: client
  }

  # Bullet configuration
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.add_footer = true
  end
end

CONFIG['extended_backend_log'] = true
CONFIG['response_schema_validation'] = true

CONFIG['frontend_host'] = 'localhost'
CONFIG['frontend_protocol'] = 'http'
