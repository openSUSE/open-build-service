# Settings specified here will take precedence over those in config/environment.rb

ENV['CACHENAMESPACE'] ||= "obs-api-test-#{Time.now.to_i}"
ENV['OBS_BACKEND_TEMP'] ||= Dir.mktmpdir('obsbackend', '/var/tmp')

Rails.application.configure do
  config.active_support.test_order = :sorted # switch to :random ?
end

OBSApi::Application.configure do
  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # We set eager loading to true in CI
  # to run with the same configuration as in production
  config.eager_load = ENV.fetch('EAGER_LOAD', '0') == '1'

  # Show full error reports and disable caching
  # local requests don't trigger the global exception handler -> set to false
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = false
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=3600'
  }

  # Tell ActionMailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Disable request forgery protection in test environment.
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

  # rubocop:disable Metrics/LineLength
  config.secret_key_base = '92b2ed725cb4d68cc5fbf86d6ba204f1dec4172086ee7eac8f083fb62ef34057f1b770e0722ade7b298837be7399c6152938627e7d15aca5fcda7a4faef91fc7'
  # rubocop:enable Metrics/LineLength

  # Bullet configuration
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.raise = false # raise an error if n+1 query occurs
  end

  # TODO: This shouldn't be needed when we switch to RSpec completely
  config.action_dispatch.rescue_responses['ActionController::InvalidAuthenticityToken'] = 950

  config.active_job.queue_adapter = :inline
end

CONFIG['response_schema_validation'] = true
CONFIG['source_url'] = "http://#{CONFIG['source_host']}:#{CONFIG['source_port']}"

# the default is not to write through, only once the backend started
# we set this to true
CONFIG['global_write_through'] = false

CONFIG['frontend_host'] = 'localhost'
CONFIG['frontend_port'] = 3203
CONFIG['frontend_protocol'] = 'http'
CONFIG['frontend_ldap_mode'] = :off

# some defaults enforced
CONFIG['apidocs_location'] = File.expand_path('../../docs/api/html/')
