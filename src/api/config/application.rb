require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require 'action_mailbox/engine'
# require 'action_text/engine'
require 'action_view/railtie'
# require 'action_cable/engine'
require 'rails/test_unit/railtie'
require 'sprockets/railtie'
require_relative '../app/lib/rails_version'

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
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1
    # FIXME: This is a known isue in RAILS 6.1 https://github.com/rails/rails/issues/40867
    config.active_record.has_many_inversing = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    if ::RailsVersion.is_7_1?
      config.autoload_lib(ignore: %w[assets tasks])
    end

    # Configuration for the application, engines, and railties goes here.
    #

    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.

    #
    # config.time_zone = 'Central Time (US & Canada)'
    # config.eager_load_paths << Rails.root.join("extras")

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Use SQL instead of Active Record's schema dumper when creating the database
    # if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    config.active_record.schema_format = :ruby

    config.log_tags = [:uuid]

    # required since rails 4.2
    config.active_job.queue_adapter = :delayed_job

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
