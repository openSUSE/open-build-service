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

CONFIG['frontend_host'] = "localhost"
CONFIG['frontend_port'] = 3203
CONFIG['frontend_protocol'] = 'http'
CONFIG['frontend_ldap_mode'] = :off

CONFIG['proxy_auth_host'] = "https://build.opensuse.org"
CONFIG['proxy_auth_login_page'] = "https://build.opensuse.org/ICSLogin"
CONFIG['proxy_auth_logout_page'] = "/cmd/ICSLogout"
CONFIG['proxy_auth_mode'] = :off

# some defaults enforced
CONFIG['theme'] = 'neutral'
CONFIG['use_static'] = nil
CONFIG['use_gravatar'] = :off

# make sure we have invalid setup for errbit
CONFIG['errbit_api_key'] = 'INVALID'
CONFIG['errbit_host'] = '192.0.2.0'
