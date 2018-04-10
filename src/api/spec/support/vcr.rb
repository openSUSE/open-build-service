# frozen_string_literal: true
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

  config.ignore_request do |request|
    # Ignore capybara identify calls. For more details:
    #   http://stackoverflow.com/questions/6119669/using-webmock-with-cucumber
    request.uri =~ /127.0.0.1:\d{5}\/__identify__/
  end
  config.ignore_hosts 'www.gravatar.com' # Ignore gravatar calls
end
