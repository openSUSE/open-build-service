# SimpleCov configuration
SimpleCov.start 'rails' do
  ENV['CODECOV_FLAG'] = ENV['TEST_SUITE']
  # NOTE: Keep filters in sync with test/test_helper.rb
  add_filter '/app/indices/'
  add_filter '/app/models/user_ldap_strategy.rb'
  add_filter '/lib/templates/'
  merge_timeout 3600
  formatter SimpleCov::Formatter::Codecov
end
