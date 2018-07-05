require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.default_cassette_options = { record: :once }
  config.allow_http_connections_when_no_cassette = true
  config.configure_rspec_metadata!
  # config.debug_logger = File.open(Rails.root.join('log', 'vcr.log'), 'w')

  config.preserve_exact_body_bytes do |http_message|
    !http_message.body.valid_encoding?
  end

  # ignore selenium requests
  config.ignore_localhost = true
  config.ignore_hosts 'selenium'
  config.ignore_hosts 'backend'
end

RSpec.configure do |config|
  config.before do
    stub_request(:get, %r{download.opensuse.org}).to_return(status: [500, 'Internal Server Error'])
    stub_request(:get, %r{www.gravatar.com}).to_return(body: File.new(Rails.root.join('app', 'assets', 'images', 'default_face.png')))
    CONFIG['global_write_through'] = true
  end
end
