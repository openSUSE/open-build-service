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
end

RSpec.configure do |config|
  # Usually we use VCR to mock the backend responses. If you want to refresh casettes
  # or record new ones you can enable writing to the backend here.
  config.before do
    stub_request(:get, /download.opensuse.org/).to_return(status: [500, 'Internal Server Error'])
    stub_request(:get, /www.gravatar.com/).to_return(body: File.new(Rails.root.join('app', 'assets', 'images', 'default_face.png')))
    # CONFIG['global_write_through'] = true
  end
  # You can also limit this to the type of test with
  # config.before(:each, type: feature) do...
end

# FIXME: Remove when VCR 6.0.1 is released
# https://github.com/vcr/vcr/pull/907/files
# rubocop:disable Style/ModuleFunction
module VCR
  class LibraryHooks
    # @private
    module WebMock
      extend self

      def with_global_hook_disabled(request)
        global_hook_disabled_requests << request

        begin
          yield
        ensure
          global_hook_disabled_requests.delete(request)
        end
      end

      def global_hook_disabled?(request)
        requests = Thread.current[:_vcr_webmock_disabled_requests]
        requests && requests.include?(request)
      end

      def global_hook_disabled_requests
        Thread.current[:_vcr_webmock_disabled_requests] ||= []
      end
    end
  end
end
# rubocop:enable Style/ModuleFunction
