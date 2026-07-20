# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # switch to :random?
  config.active_support.test_order = :sorted

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Show full error reports.
  config.consider_all_requests_local = true

  # FIXME: There are some specs that depend on Rails.cache to function...
  config.cache_store = :memory_store

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Turn of the asset pipeline log
  config.assets.quiet = true

  # Do not render error pages for any exception
  # config.action_dispatch.show_exceptions = :none
  # TODO: This shouldn't be needed when we switch to RSpec completely
  config.action_dispatch.rescue_responses['ActionController::InvalidAuthenticityToken'] = 950

  # Enable request forgery protection in test environment. To catch things early.
  config.action_controller.allow_forgery_protection = true

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Bullet configuration
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.raise = false # raise an error if n+1 query occurs
  end

  # Use inline queue adapter to executed the job immediately
  config.active_job.queue_adapter = :inline

  # Access to rack session for feature specs
  config.middleware.use RackSessionAccess::Middleware
end

### Setup CONFIG defaults
# FIXME: This is used in specs as shortcut for the backend URL a lot. It belongs to the spec setup...
CONFIG['source_url'] = "http://#{CONFIG['source_host']}:#{CONFIG['source_port']}"
# Only once the backend started we set this to true...
CONFIG['global_write_through'] = false

# Minitest runs the backend itself on localhost
if ENV['RUNNING_MINITEST']
  CONFIG['source_host'] = 'localhost'
  CONFIG['source_port'] = '3200'
end

# If we run minitest in docker then we need to tell it to not
# start the backend and try the backend container
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

