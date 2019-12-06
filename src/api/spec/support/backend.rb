require 'webmock/rspec'

# Allow connections to localhost
WebMock.disable_net_connect!(allow: ['0.0.0.0', 'selenium', '127.0.0.1', CONFIG['source_url']])

RSpec.configure do |config|
  config.before do |ex|
    stub_request(:get, %r{download.opensuse.org}).to_return(status: [500, 'Internal Server Error'])
    stub_request(:get, %r{www.gravatar.com}).to_return(body: File.new(Rails.root.join('app', 'assets', 'images', 'default_face.png')))

    CONFIG['global_write_through'] = true

    # model tests get a fake backend unless backend: true
    if ex.metadata[:type] == :model && !ex.metadata[:backend]
      stub_request(:any, Regexp.new(CONFIG['source_url'])).to_return(body: '<status/>')
    end
  end
end
