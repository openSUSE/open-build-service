require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"
require "sprockets/railtie"

### bundler_ext support
# WARNING: You will be on your own with problems if you use bundler_ext, we
# only ensure our app works with the exact gems specified in our Gemfile.lock
# For more information see the bundler_ext documentation.
# https://rubygems.org/gems/bundler_ext
gemfile_in = File.expand_path('../Gemfile.in', __dir__)
if File.exist?(gemfile_in)
  require 'bundler_ext'
  BundlerExt.system_require(gemfile_in, *Rails.groups(assets: %w[development test]))
else
  # Require the gems listed in Gemfile
  # Assets should be precompiled for production (so we don't need the gems loaded then)
  Bundler.require(*Rails.groups(assets: %w[development test]))
end

module OBSApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks templates haml-lint rubocop])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Raise ActionController::UnpermittedParameters when parameters that are not explicitly permitted are found.
    # Makes it easier to debug in development/testing and less dangerous in production.
    config.action_controller.action_on_unpermitted_parameters = :raise

        # we're not threadsafe
    config.allow_concurrency = false

    # we don't want factory_bot to interfer with the legacy test suite
    # based on minitest
    config.generators do |g|
      g.factory_bot(false)
      g.test_framework :rspec
    end

    # Classes required by YAML.safe_load used by paper_trail for loading date and time values
    config.active_record.yaml_column_permitted_classes = [Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone]
  end
end
