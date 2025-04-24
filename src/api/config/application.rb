require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_mailer/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'active_storage/engine'
require 'sprockets/railtie'
require 'rails/test_unit/railtie'

# The bundler_ext rubygem disables enforcement of gem versions in
# `Gemfile.lock` in favour of the basic constraints defined in the file
# `Gemfile.in`. The bundler_ext rubygem is not part of the OBS bundle, so you
# need to explicitly install it, however you install gems on your system. Eg.
# with gem or your system package manager. Then create the appropriate file
# with `cp Gemfile Gemfile.in`. For more information see the bundler_ext
# documentation.

# WARNING: You will be on your own with problems if you use bundler_ext, we
# only ensure our app works with the exact gems specified in our Gemfile.lock
gemfile_in = File.expand_path('../Gemfile.in', __dir__)
if File.exist?(gemfile_in)
  require 'bundler_ext'
  BundlerExt.system_require(gemfile_in, *Rails.groups(assets: %w[development test]))
else
  # Assets should be precompiled for production (so we don't need the gems loaded then)
  Bundler.require(*Rails.groups(assets: %w[development test]))
end

require_relative '../lib/rabbitmq_bus'

module OBSApi
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Enable rails version 7.0 defaults
    config.load_defaults 7.0
    # FIXME: This is a known isue in RAILS 6.1 https://github.com/rails/rails/issues/40867
    config.active_record.has_many_inversing = false

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

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

    # Use SQL instead of Active Record's schema dumper when creating the database
    # if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    config.active_record.schema_format = :ruby

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
    # config.action_controller.session_store :active_record_store

    # put the rubygem requirements here for a clean handling
    # rails gems:install (installs the needed gems)
    # rails gems:unpack (this unpacks the gems to vendor/gems)

    # required since rails 4.2
    config.active_job.queue_adapter = :delayed_job

    # Activate observers that should always be running
    # config.active_record.observers = :cacher, :garbage_collector

    # Make Active Record use UTC-base instead of local time
    # config.active_record.default_timezone = :utc

    config.action_controller.perform_caching = true

    config.active_record.cache_versioning = true
    config.active_record.collection_cache_versioning = false

    # Disable partial writes to avoid causing incorrect values
    # to be inserted when changing the default value of a column.
    config.active_record.partial_inserts = false

    config.action_controller.action_on_unpermitted_parameters = :raise

    config.action_dispatch.rescue_responses['Backend::Error'] = 500
    config.action_dispatch.rescue_responses['Timeout::Error'] = 408
    config.action_dispatch.rescue_responses['ActionController::InvalidAuthenticityToken'] = 403

    # avoid a warning
    I18n.enforce_available_locales = true

    config.assets.configure do |env|
      # https://github.com/rails/sprockets/issues/581
      env.export_concurrent = false
    end

    # we're not threadsafe
    config.allow_concurrency = false

    # we don't want factory_bot to interfer with the legacy test suite
    # based on minitest
    config.generators do |g|
      g.factory_bot(false)
      g.test_framework :rspec
      g.orm :active_record, primary_key_type: :integer
    end

    # View components
    # Previews are enabled by default in development and test environments (this is the default value)
    # config.view_component.show_previews = true
    # Preview classes of view components live in:
    config.view_component.preview_paths << Rails.root.join('spec/components/previews')
    # Previews are served at http://HOST:PORT/rails/view_components (this is the default value)
    # config.view_component.preview_route = "/rails/view_components"
    # Set the default layout for previews (app/views/layouts/NAME.html.haml)
    config.view_component.default_preview_layout = 'view_component_previews'
    # Below the preview, display a syntax highlighted source code example of the usage of the view component
    config.view_component.show_previews_source = true

    # Classes required by YAML.safe_load used by paper_trail for loading date and time values
    config.active_record.yaml_column_permitted_classes = [Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone]
  end
end
