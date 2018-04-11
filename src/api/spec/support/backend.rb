# frozen_string_literal: true

# Allow connections to localhost
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # build each factory and call #valid? on it
  config.before(:suite) do
    # Backend::Test.start
  end
end

# for mocking the backend
require 'support/vcr'
