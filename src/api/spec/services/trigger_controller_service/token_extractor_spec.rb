require 'rails_helper'
require 'ostruct'

RSpec.describe ::TriggerControllerService::TokenExtractor do
  let(:request) { OpenStruct.new(env: { 'HTTP_X_GITLAB_EVENT' => 'Push Hook', 'HTTP_X_GITLAB_TOKEN' => 'XY123456' }) }
  let(:token_extractor) { described_class.new(request) }

  describe '.new' do
    it { expect { token_extractor }.not_to raise_error }
  end

  describe '#extract_auth_token' do
    it { expect(token_extractor.extract_auth_token).to eq('Token XY123456') }

    context 'with HTTP_AUTHORIZATION' do
      let(:request) { OpenStruct.new(env: { 'HTTP_AUTHORIZATION' => 'FOO1234' }) }
      it { expect(token_extractor.extract_auth_token).to eq('FOO1234') }
    end
  end

  describe '#valid?' do
    before do
      token_extractor.extract_auth_token
    end

    it { expect(token_extractor).to be_valid }
  end
end
