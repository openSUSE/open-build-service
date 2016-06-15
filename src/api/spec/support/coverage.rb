# start coverage tracking
Coveralls.wear_merged!('rails')

# SimpleCov configuration
SimpleCov.start 'rails' do
  add_filter '/app/indices/'
  add_filter '/app/models/user_ldap_strategy.rb'
  merge_timeout 3600
  formatter Coveralls::SimpleCov::Formatter
end
