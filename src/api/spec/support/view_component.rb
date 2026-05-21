require 'view_component/test_helpers'
# To write view component specs with Capybara matchers
require 'capybara/rspec'

module ComponentsAuthentication
  def login(user)
    User.session = user
  end

  def logout
    User.session = nil
  end
end

RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
  config.include ComponentsAuthentication, type: :component
end
