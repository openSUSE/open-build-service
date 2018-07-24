require_relative 'boot'

require 'rails/all'

# Assets should be precompiled for production (so we don't need the gems loaded then)
Bundler.require(*Rails.groups(assets: ['development', 'test']))
require_relative '../lib/engines/base.rb'
require_relative '../lib/rabbitmq_bus.rb'
OBSEngine.load_engines

module OBSApi
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)
    config.eager_load_paths << Rails.root.join('lib', 'backend')

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rails -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Skip frameworks you're not going to use
    # config.frameworks -= [ :action_web_service, :active_resource ]

    # Add additional load paths for your own custom dirs
    # config.load_paths += %W( #{Rails.root}/extras )

    # Rails.root is not working directory when running under lighttpd, so it has
    # to be added to load path
    # config.load_paths << Rails.root unless config.load_paths.include? Rails.root

    # Force all environments to use the same logger level
    # (by default production uses :info, the others :debug)
    # config.log_level = :debug

    config.log_tags = [:uuid]

    # Use the database for sessions instead of the file system
    # (create the session table with 'rails create_sessions_table')
    # config.action_controller.session_store = :active_record_store

    # put the rubygem requirements here for a clean handling
    # rails gems:install (installs the needed gems)
    # rails gems:unpack (this unpacks the gems to vendor/gems)

    # required since rails 4.2
    config.active_job.queue_adapter = :delayed_job

    # Activate observers that should always be running
    # config.active_record.observers = :cacher, :garbage_collector

    # Make Active Record use UTC-base instead of local time
    # config.active_record.default_timezone = :utc

    config.active_record.schema_format = :sql

    config.action_controller.perform_caching = true

    config.assets.js_compressor = :uglifier

    config.assets.precompile += ['webui/application/cm2/index.js',
                                 'webui/application/cm2/index-diff.js',
                                 'webui/application/cm2/index-xml.js',
                                 'webui/application/cm2/index-prjconf.js']

    config.action_controller.action_on_unpermitted_parameters = :raise

    config.action_dispatch.rescue_responses['ActiveXML::Transport::UnauthorizedError'] = 401
    config.action_dispatch.rescue_responses['ActiveXML::Transport::ConnectionError'] = 503
    config.action_dispatch.rescue_responses['ActiveXML::Transport::Error'] = 500
    config.action_dispatch.rescue_responses['Timeout::Error'] = 408
    config.action_dispatch.rescue_responses['ActionController::InvalidAuthenticityToken'] = 403

    # avoid a warning
    I18n.enforce_available_locales = true

    # we're not threadsafe
    config.allow_concurrency = false

    # we don't want factory_bot to interfer with the legacy test suite
    # based on minitest
    config.generators do |g|
      g.factory_bot false
      g.test_framework :rspec
    end

    unless Rails.env.test?
      config.after_initialize do
        # See Rails::Configuration for more options
      end
    end
  end
end
