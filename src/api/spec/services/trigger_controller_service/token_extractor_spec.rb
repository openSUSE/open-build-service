require 'rails_helper'
require 'ostruct' # for OpenStruct
require 'stringio' # for StringIO

RSpec.describe TriggerControllerService::TokenExtractor do
  describe '#call' do
    subject { described_class.new(request).call }

    let(:token) { create(:service_token) }
    let(:request_body) { 'Lorem Ipsum' }

    context 'without a token ID in the params and a token in HTTP headers' do
      let(:request) { OpenStruct.new(params: {}, body: StringIO.new(request_body), env: {}) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'with the ID of a nonexistent token in the params' do
      let(:request) { OpenStruct.new(params: { id: -1 }, body: StringIO.new(request_body), env: {}) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'with the ID of a token in the params and a valid signature in the HTTP headers' do
      let(:request) { OpenStruct.new(params: { id: token.id }, body: StringIO.new(request_body), env: {}) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    ['HTTP_X_OBS_SIGNATURE', 'HTTP_X_HUB_SIGNATURE_256', 'HTTP_X-Pagure-Signature-256'].each do |http_header|
      context "with the ID of a token in the params and the HTTP header #{http_header} containing a signature of the request body" do
        let(:signature) { OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), token.string, request_body) }
        let(:request) do
          OpenStruct.new(params: { id: token.id }, body: StringIO.new(request_body),
                         env: { http_header => "sha256=#{signature}" })
        end

        it 'returns the token' do
          expect(subject).to eq(token)
        end
      end
    end

    context 'with a wrong token in the HTTP header HTTP_X_GITLAB_TOKEN' do
      let(:request) do
        OpenStruct.new(params: {}, body: StringIO.new(request_body),
                       env: { 'HTTP_X_GITLAB_TOKEN' => 'Québec' })
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'with a token in the HTTP header HTTP_X_GITLAB_TOKEN' do
      let(:request) do
        OpenStruct.new(params: {}, body: StringIO.new(request_body),
                       env: { 'HTTP_X_GITLAB_TOKEN' => token.string })
      end

      it 'returns the token' do
        expect(subject).to eq(token)
      end
    end

    context 'with an incorrectly formatted HTTP header HTTP_AUTHORIZATION' do
      let(:request) do
        OpenStruct.new(params: {}, body: StringIO.new(request_body),
                       env: { 'HTTP_AUTHORIZATION' => token.string })
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'with a token in the HTTP header HTTP_AUTHORIZATION' do
      let(:request) do
        OpenStruct.new(params: {}, body: StringIO.new(request_body),
                       env: { 'HTTP_AUTHORIZATION' => "Token #{token.string}" })
      end

      it 'returns the token' do
        expect(subject).to eq(token)
      end
    end
  end
end
