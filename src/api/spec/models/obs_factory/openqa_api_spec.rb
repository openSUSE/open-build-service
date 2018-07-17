require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ObsFactory::OpenqaApi do
  let(:openqa_api) { ObsFactory::OpenqaApi.new('https://some_url.com/') }

  describe '::new' do
    it { expect(openqa_api.base_url).to eq('https://some_url.com/api/v1/') }
  end
end

