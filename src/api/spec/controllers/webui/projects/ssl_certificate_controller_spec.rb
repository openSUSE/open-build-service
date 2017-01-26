require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::Projects::SslCertificateController, type: :controller do
  describe 'GET #show' do
    let(:project) { create(:project, name: "test_project", title: "Test Project") }
    let(:backend_url) { "#{CONFIG['source_url']}#{Project::KeyInfo.backend_url_with_ssl(project.name)}" }
    let(:gpg_public_key) { Faker::Lorem.characters(1024) }

    before do
      Rails.cache.clear
      # NOTE: we're not using VCR here because the backend does not have the obs signer setup by default
      stub_request(:get, backend_url).and_return(body: keyinfo_response)

      get :show, params: { project_name: project.name }
    end

    context 'with a project that has an ssl certificate' do
      let(:ssl_certificate) { Faker::Lorem.characters(1024) }
      let(:keyinfo_response) do
        %(<keyinfo project="Test"><pubkey algo="rsa">#{gpg_public_key}</pubkey><sslcert>#{ssl_certificate}</sslcert></keyinfo>)
      end

      it { expect(response.header['Content-Disposition']).to include('attachment') }
      it { expect(response.body.strip).to eq(ssl_certificate) }
    end

    context 'with a project that has no ssl certificate' do
      let(:keyinfo_response) do
        %(<keyinfo project="Test"><pubkey algo="rsa">#{gpg_public_key}</pubkey></keyinfo>)
      end

      it { expect(response.status).to eq(404) }
    end
  end
end
