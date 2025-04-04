require "active_support/core_ext/integer/time"

ENV['CACHENAMESPACE'] ||= "obs-api-test-#{Time.now.to_i}"
ENV['OBS_BACKEND_TEMP'] ||= Dir.mktmpdir('obsbackend', '/var/tmp')

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  config.active_support.test_order = :sorted # switch to :random ?
end

# This isn't going to change since this is how we configure Rails
# rubocop:disable Metrics/BlockLength
OBSApi::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  config.cache_classes = true

  # Eager loading loads your whole application. When running a single test locally,
  # this probably isn't necessary. It's a good idea to do in a continuous integration
  # system, or in some way before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Show full error reports and disable caching.
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Raise exceptions instead of rendering exception templates.
  # config.action_dispatch.show_exceptions = :none

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Enable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = true

  config.action_mailer.perform_caching = false

  config.cache_store = :memory_store

  config.active_support.deprecation = :log
  # Print deprecation notices to the stderr.
  #  config.active_support.deprecation = :stderr

  # Expands the lines which load the assets
  config.assets.debug = false
  config.assets.log = nil
  # turn of the asset pipeline log. Previously done by quiet_assets gem.
  config.assets.quiet = true
  config.secret_key_base = '92b2ed725cb4d68cc5fbf86d6ba204f1dec4172086ee7eac8f083fb62ef34057f1b770e0722ade7b298837be7399c6152938627e7d15aca5fcda7a4faef91fc7'

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Bullet configuration
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.raise = false # raise an error if n+1 query occurs
  end

  # TODO: This shouldn't be needed when we switch to RSpec completely
  config.action_dispatch.rescue_responses['ActionController::InvalidAuthenticityToken'] = 950

  config.active_job.queue_adapter = :inline

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true
end
# rubocop:enable Metrics/BlockLength

CONFIG['response_schema_validation'] = true
CONFIG['source_url'] = "http://#{CONFIG['source_host']}:#{CONFIG['source_port']}"

# the default is not to write through, only once the backend started
# we set this to true
CONFIG['global_write_through'] = false

CONFIG['frontend_host'] = 'localhost'
CONFIG['frontend_port'] = 3203
CONFIG['frontend_protocol'] = 'http'

if ENV['RUNNING_MINITEST']
  CONFIG['source_host'] = 'localhost'
  CONFIG['source_port'] = '3200'
end

if ENV['RUNNING_MINITEST_WITH_DOCKER']
  ENV['BACKEND_STARTED'] = "1"
  CONFIG['source_host'] = 'backend'
  CONFIG['source_port'] = '5352'
end

# Display fake sponsors above the footer on every page
CONFIG['sponsors'] = [
  ActiveSupport::HashWithIndifferentAccess.new(
    name: 'Greens Food Supplies',
    description: 'Direct delivery service',
    icon: 'sponsor_greens-food-supplies',
    url: '#'
  ),
  ActiveSupport::HashWithIndifferentAccess.new(
    name: 'Auto Speed',
    description: 'Same day auto parts',
    icon: 'sponsor_auto-speed',
    url: '#'
  )
]

# Making sure that Backend::Logger.info is fully executed to catch potential errors
CONFIG['extended_backend_log'] = true
