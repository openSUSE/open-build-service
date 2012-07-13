OBSWebUI::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Log error messages when you accidentally call methods on nil
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Print deprecation notices to the log
  config.active_support.deprecation = :log

  config.cache_store = :memory_store
end

FRONTEND_HOST = "localhost"
FRONTEND_PORT = 3203
FRONTEND_PROTOCOL = 'http'
FRONTEND_LDAP_MODE = :off

PROXY_AUTH_HOST = "https://build.opensuse.org"
PROXY_AUTH_LOGIN_PAGE = "https://build.opensuse.org/ICSLogin"
PROXY_AUTH_LOGOUT_PAGE = "/cmd/ICSLogout"
PROXY_AUTH_MODE = :off

