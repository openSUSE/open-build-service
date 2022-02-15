require 'rubocop/rspec/support'

RSpec.configure do |config|
  # expect_offense and expect_no_offense matchers
  config.include RuboCop::RSpec::ExpectOffense
end
