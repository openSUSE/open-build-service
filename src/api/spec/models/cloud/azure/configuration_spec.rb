# frozen_string_literal: true
require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Cloud::Azure::Configuration, type: :model do
  describe 'data encryption' do
    let(:config) { create(:azure_configuration, application_id: 'Hey OBS!', application_key: 'Hey OBS?') }
    let(:secret_key) { OpenSSL::PKey::RSA.new(File.read(Rails.root.join('spec', 'support', 'files', 'cloudupload_secret_key_tests.pem'))) }
    let(:public_key) { File.read(Rails.root.join('spec', 'support', 'files', 'cloudupload_public_key.txt')) }

    before do
      stub_request(:get, "#{CONFIG['source_url']}/cloudupload/_pubkey").and_return(body: public_key)
    end

    context '#application_id' do
      it { expect(secret_key.private_decrypt(Base64.decode64(config.application_id))).to eq('Hey OBS!') }
    end

    context '#application_key' do
      it { expect(secret_key.private_decrypt(Base64.decode64(config.application_key))).to eq('Hey OBS?') }
    end
  end
end
