require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.default_cassette_options = { record: :new_episodes }
  config.allow_http_connections_when_no_cassette = true
  config.configure_rspec_metadata!

  config.preserve_exact_body_bytes do |http_message|
    !http_message.body.valid_encoding?
  end

  # ignore selenium requests
  config.ignore_localhost = true
  config.ignore_hosts 'www.gravatar.com' # Ignore gravatar calls
  config.ignore_hosts 'selenium'
end

RSpec.configure do |config|
  # Usually we use VCR to mock the backend responses. If you want to refresh casettes
  # or record new ones you can enable writing to the backend here.
  config.before do
    # CONFIG['global_write_through'] = true
  end
  # You can also limit this to the type of test with
  # config.before(:each, type: feature) do...
end
