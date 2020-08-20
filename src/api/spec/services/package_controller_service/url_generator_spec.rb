require 'rails_helper'

RSpec.describe ::PackageControllerService::URLGenerator do
  describe '#get_frontend_url_for' do
    let(:url_generator) { ::PackageControllerService::URLGenerator.new({}) }

    it 'generates a url' do
      url = url_generator.get_frontend_url_for(controller: 'foo', host: 'bar.com', port: 80, protocol: 'http')
      expect(url).to eq('http://bar.com:80/foo')
    end
  end
end
