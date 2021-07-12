require 'view_component/test_helpers'
# To write view component specs with Capybara matchers
require 'capybara/rspec'

RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
end
