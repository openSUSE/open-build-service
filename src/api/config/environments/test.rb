require "active_support/core_ext/integer/time"

ENV['OBS_BACKEND_TEMP'] ||= Dir.mktmpdir('obsbackend', '/var/tmp')

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

OBSApi::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Turn false under Spring and add config.action_view.cache_template_loading = true.
  config.cache_classes = true

  # Eager loading loads your whole application. When running a single test locally,
  # this probably isn't necessary. It's a good idea to do in a continuous integration
  # system, or in some way before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :memory_store

  # Raise exceptions instead of rendering exception templates.
  # config.action_dispatch.show_exceptions = :none

  # Enable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = true

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  config.active_job.queue_adapter = :inline

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true
end

# the default is not to write through, only once the backend started
# we set this to true
CONFIG['global_write_through'] = false

if ENV['RUNNING_MINITEST']
  CONFIG['source_host'] = 'localhost'
  CONFIG['source_port'] = '3200'
end

if ENV['RUNNING_MINITEST_WITH_DOCKER']
  ENV['BACKEND_STARTED'] = "1"
  CONFIG['source_host'] = 'backend'
  CONFIG['source_port'] = '5352'
end

CONFIG['source_url'] = "http://#{CONFIG['source_host']}:#{CONFIG['source_port']}"
