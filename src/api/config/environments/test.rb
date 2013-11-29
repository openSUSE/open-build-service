# Settings specified here will take precedence over those in config/environment.rb

ENV['CACHENAMESPACE'] ||= "obs-api-test-#{Time.now.to_i}"

OBSApi::Application.configure do

  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true

  # Show full error reports and disable caching
  # local requests don't trigger the global exception handler -> set to false
  config.consider_all_requests_local = false
  config.action_controller.perform_caching             = false

  # Tell ActionMailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :file

  config.cache_store = :dalli_store, '127.0.0.1:11211', {namespace: ENV['CACHENAMESPACE'], expires_in: 1.hour }

  config.active_support.deprecation = :log
  
  config.eager_load = false

  # Expands the lines which load the assets
  config.assets.debug = false
  config.assets.log = nil

  config.secret_key_base = '92b2ed725cb4d68cc5fbf86d6ba204f1dec4172086ee7eac8f083fb62ef34057f1b770e0722ade7b298837be7399c6152938627e7d15aca5fcda7a4faef91fc7'
end

CONFIG['source_host'] = "localhost"
CONFIG['source_port'] = 3200

CONFIG['proxy_auth_mode']=:off

CONFIG['response_schema_validation'] = true

# the default is not to write through, only once the backend started
# we set this to true
CONFIG['global_write_through'] = false

# make sure we have invalid setup for errbit
CONFIG['errbit_api_key'] = 'INVALID'

CONFIG['frontend_host'] = "localhost"
CONFIG['frontend_port'] = 3203
CONFIG['frontend_protocol'] = 'http'
CONFIG['frontend_ldap_mode'] = :off

CONFIG['proxy_auth_host'] = "https://build.opensuse.org"
CONFIG['proxy_auth_login_page'] = "https://build.opensuse.org/ICSLogin"
CONFIG['proxy_auth_logout_page'] = "/cmd/ICSLogout"
CONFIG['proxy_auth_mode'] = :off

# some defaults enforced
CONFIG['use_static'] = nil


