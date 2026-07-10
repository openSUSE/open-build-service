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

module OBSApi
  class Application < Rails::Application
    # Enable rails version 7.0 defaults
    config.load_defaults 7.0

    # required since rails 4.2
    config.active_job.queue_adapter = :delayed_job

    config.action_controller.perform_caching = true

    config.active_record.collection_cache_versioning = false

    config.action_controller.action_on_unpermitted_parameters = :raise

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
    end

    # View components
    # Previews are enabled by default in development and test environments (this is the default value)
    # config.view_component.show_previews = true
    # Preview classes of view components live in:
    config.view_component.previews.paths << Rails.root.join('spec/components/previews')
    # Previews are served at http://HOST:PORT/rails/view_components (this is the default value)
    # config.view_component.preview_route = "/rails/view_components"
    # Set the default layout for previews (app/views/layouts/NAME.html.haml)
    config.view_component.previews.default_layout = 'view_component_previews'
    # Below the preview, display a syntax highlighted source code example of the usage of the view component
    config.view_component.show_previews_source = true

    # Classes required by YAML.safe_load used by paper_trail for loading date and time values
    config.active_record.yaml_column_permitted_classes = [Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone]
  end
end
