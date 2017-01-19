require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Source::KeyInfoController, type: :controller do
  describe 'GET #show' do
    let(:user) { create(:confirmed_user) }
    let(:project) { create(:project, name: "test_project", title: "Test Project") }
    let(:backend_url) { "#{CONFIG['source_url']}#{Project::KeyInfo.backend_url(project.name)}" }
    let(:gpg_public_key) { Faker::Lorem.characters(1024) }
    let(:ssl_certificate) { Faker::Lorem.characters(1024) }
    let(:keyinfo_response) do
      %(<keyinfo project="Test"><pubkey algo="rsa">#{gpg_public_key}</pubkey><sslcert>#{ssl_certificate}</sslcert></keyinfo>)
    end

    before do
      Rails.cache.clear
      # NOTE: we're not using VCR here because the backend does not have the obs signer setup by default
      stub_request(:get, backend_url).and_return(body: keyinfo_response)
      login(user)

      get :show, params: { format: :xml, project: project.name }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(response.body).to eq(keyinfo_response) }
  end
end
