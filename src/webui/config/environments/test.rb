# Settings specified here will take precedence over those in config/environment.rb

# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils    = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false

# Tell ActionMailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test

config.cache_store = :memory_store

config.action_controller.allow_forgery_protection = false

FRONTEND_HOST = "localhost"
FRONTEND_PORT = 3203
FRONTEND_PROTOCOL = 'http'

ICHAIN_HOST = "https://build.opensuse.org"
ICHAIN_MODE = "off"

config.gem 'webrat', :version => ">=0.4.3"

