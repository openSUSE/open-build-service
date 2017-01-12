require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::Projects::PublicKeyController, type: :controller do
  describe 'GET #show' do
    let(:project) { create(:project, name: "test_project", title: "Test Project") }
    let(:backend_url) { CONFIG['source_url'] + Project::KeyInfo.send(:backend_url, project.name) }

    before do
      Rails.cache.clear
      stub_request(:get, backend_url).and_return(body: keyinfo_response)

      get :show, params: { project_name: project.name }
    end

    context 'with a project that has a public key' do
      let(:gpg_public_key) { Faker::Lorem.characters(1024) }
      let(:keyinfo_response) do
        %(<keyinfo project="Test"><pubkey algo="rsa">#{gpg_public_key}</pubkey></keyinfo>)
      end

      it { expect(response.header['Content-Disposition']).to include('attachment') }
      it { expect(response.body.strip).to eq(gpg_public_key) }
    end

    context 'with a project that has no public key' do
      let(:keyinfo_response) { '<keyinfo />' }

      it { expect(response.status).to eq(404) }
    end
  end
end
