# start coverage tracking
Coveralls.wear_merged!('rails')

# SimpleCov configuration
SimpleCov.start 'rails' do
  # NOTE: Keep filters in sync with test/test_helper.rb
  add_filter '/app/indices/'
  add_filter '/app/models/user_ldap_strategy.rb'
  add_filter '/lib/templates/'
  add_filter '/lib/memory_debugger.rb'
  add_filter '/lib/memory_dumper.rb'
  merge_timeout 3600
  formatter Coveralls::SimpleCov::Formatter
end
