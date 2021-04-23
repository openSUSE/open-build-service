require 'rails_helper'

RSpec.describe Token::Service do
  let(:user) { create(:user) }
  let(:token) { create(:service_token, user: user) }
  let(:body) { { hello: :world }.to_s }

  describe '#valid_request?' do
    context 'for a valid request' do
      let(:signature) { 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), token.string, body) }

      it { expect(token).to be_valid_signature(signature, body) }
    end

    context 'for an invalid request' do
      let(:signature) { 'sha1=just-not-valid' }

      it { expect(token).not_to be_valid_signature(signature, body) }
      it { expect(token).not_to be_valid_signature(nil, body) }
    end
  end
end
