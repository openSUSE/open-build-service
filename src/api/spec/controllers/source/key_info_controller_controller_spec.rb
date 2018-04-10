# frozen_string_literal: true
require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Source::KeyInfoController, type: :controller do
  describe 'GET #show' do
    let(:user) { create(:confirmed_user) }
    let(:project) { create(:project, name: 'test_project', title: 'Test Project') }
    let(:gpg_public_key) { Faker::Lorem.characters(1024) }
    let(:ssl_certificate) { Faker::Lorem.characters(1024) }
    let(:keyinfo_response) do
      <<-XML
        <keyinfo project="Test">
          <pubkey keyid="0292741d" algo="rsa" keysize="2048" expires="1554571193" fingerprint="f9fe d209 ff53 6d54 ec96 916a 45d4 5b02 0292 741d">
            #{gpg_public_key}
          </pubkey>
          <sslcert>
            #{ssl_certificate}
          </sslcert>
        </keyinfo>
      XML
    end

    before do
      Rails.cache.clear
      # NOTE: we're not using VCR here because the backend does not have the obs signer setup by default
      keyinfo_url = "#{CONFIG['source_url']}/source/#{CGI.escape(project.name)}/_keyinfo?donotcreatecert=1&withsslcert=1"
      stub_request(:get, keyinfo_url).and_return(body: keyinfo_response)

      login(user)

      get :show, params: { format: :xml, project: project.name }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(response.body).to eq(keyinfo_response) }
  end
end
