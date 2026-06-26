# Allow connections to localhost
WebMock.disable_net_connect!(allow_localhost: true)

# for mocking the backend
require 'support/vcr'
