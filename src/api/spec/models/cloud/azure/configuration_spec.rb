require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Cloud::Azure::Configuration, type: :model, vcr: true do
  describe 'data encryption' do
    let(:config) { create(:azure_configuration, application_id: 'Hey OBS!', application_key: 'Hey OBS?') }

    context '#application_id' do
      it { expect(config.application_id).to match(/PGP/) }
    end

    context '#application_key' do
      it { expect(config.application_id).to match(/PGP/) }
    end
  end

  describe 'validations' do
    it 'allows application_id and application_key to be empty' do
      config = Cloud::Azure::Configuration.create(application_id: nil, application_key: nil)
      expect(config).to be_valid
    end

    it 'application_id requires an application_key to be present' do
      config = Cloud::Azure::Configuration.create(application_id: 'test', application_key: nil)
      expect(config).to be_invalid
    end

    it 'application_key requires an application_id to be present' do
      config = Cloud::Azure::Configuration.create(application_key: 'test', application_id: nil)
      expect(config).to be_invalid
    end
  end
end
