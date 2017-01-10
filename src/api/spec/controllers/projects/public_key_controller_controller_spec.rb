require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Projects::PublicKeyController, type: :controller, vcr: true do
  describe 'GET #show' do
    let(:project) do
      create(
        :project,
        name: "test_project",
        title: "Test Project"
      )
    end

    let(:backend_url) { CONFIG['source_url'] + PublicKey.send(:backend_url, project.name) }

    before do
      stub_request(:get, backend_url).and_return(body: keyinfo_response)

      get :show, params: { format: :xml, project_name: project.name }
    end

    context 'with a project that has a public key and an ssl certificate' do
      let(:gpg_public_key) { Faker::Lorem.characters(1024) }
      let(:ssl_certificate) { Faker::Lorem.characters(1024) }
      let(:keyinfo_response) do
        %(<keyinfo project="Test"><pubkey algo="rsa">#{gpg_public_key}</pubkey><sslcert>#{ssl_certificate}</sslcert></keyinfo>)
      end

      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:show) }
    end

    context 'with a project that has a public key and no ssl certificate' do
      let(:gpg_public_key) { Faker::Lorem.characters(1024) }
      let(:keyinfo_response) do
        %(<keyinfo project="Test"><pubkey algo="rsa">#{gpg_public_key}</pubkey></keyinfo>)
      end

      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:show) }
    end

    context 'with a project that has no public key' do
      let(:keyinfo_response) { '<keyinfo />' }

      it { expect(response.status).to eq(404) }
    end
  end
end
