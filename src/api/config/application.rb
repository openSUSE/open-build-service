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

# Assets should be precompiled for production (so we don't need the gems loaded then)
Bundler.require(*Rails.groups(assets: %w[development test]))

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
# Bundler.require(*Rails.groups)

require_relative '../lib/rabbitmq_bus'

module OBSApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Disable partial writes to avoid causing incorrect values
    # to be inserted when changing the default value of a column.
    config.active_record.partial_inserts = false

    config.action_controller.action_on_unpermitted_parameters = :raise

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
