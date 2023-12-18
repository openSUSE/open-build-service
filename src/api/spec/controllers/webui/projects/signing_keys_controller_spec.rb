require 'webmock/rspec'

RSpec.describe Webui::Projects::SigningKeysController do
  describe 'GET #download' do
    let(:project) { create(:project, name: 'test_project', title: 'Test Project') }

    before do
      Rails.cache.clear
      # NOTE: we're not using VCR here because the backend does not have the obs signer setup by default
      keyinfo_url = "#{CONFIG['source_url']}/source/#{CGI.escape(project.name)}/_keyinfo?donotcreatecert=1&withsslcert=1"
      stub_request(:get, keyinfo_url).and_return(body: keyinfo_response)

      get :download, params: { project_name: project.name, kind: kind_param }
    end

    context 'with a project that has a public key' do
      let(:kind_param) { 'gpg' }
      let(:gpg_public_key) { Faker::Lorem.characters(number: 1024) }
      let(:keyinfo_response) do
        <<-XML
          <keyinfo project="Test">
            <pubkey keyid="0292741d" algo="rsa" keysize="2048" expires="1554571193" fingerprint="f9fe d209 ff53 6d54 ec96 916a 45d4 5b02 0292 741d">
              #{gpg_public_key}
            </pubkey>
          </keyinfo>
        XML
      end

      it { expect(response.header['Content-Disposition']).to include('attachment') }
      it { expect(response.body.strip).to eq(gpg_public_key) }
    end

    context 'with a project that has no public key' do
      let(:kind_param) { 'gpg' }
      let(:keyinfo_response) { '<keyinfo />' }

      it { is_expected.to redirect_to(project_signing_keys_path(project)) }
      it { expect(flash[:error]).not_to be_empty }
    end

    context 'with a project that has an ssl certificate' do
      let(:kind_param) { 'ssl' }
      let(:ssl_certificate) { Faker::Lorem.characters(number: 1024) }
      let(:keyinfo_response) do
        <<-XML
          <keyinfo project="Test">
            <sslcert serial="0xb911712e27dc32d8" keyid="4872723" subject="Some random string" algo="rsa" keysize="2048" begins="1511570476" expires="1580690476">
              #{ssl_certificate}
            </sslcert>
          </keyinfo>
        XML
      end

      it { expect(response.header['Content-Disposition']).to include('attachment') }
      it { expect(response.body.strip).to eq(ssl_certificate) }
    end

    context 'with a project that has no ssl certificate' do
      let(:kind_param) { 'ssl' }
      let(:gpg_public_key) { Faker::Lorem.characters(number: 1024) }
      let(:keyinfo_response) do
        <<-XML
          <keyinfo project="Test">
            <pubkey keyid="0292741d" algo="rsa" keysize="2048" expires="1554571193" fingerprint="f9fe d209 ff53 6d54 ec96 916a 45d4 5b02 0292 741d">
              #{gpg_public_key}
            </pubkey>
          </keyinfo>
        XML
      end

      it { is_expected.to redirect_to(project_signing_keys_path(project)) }
      it { expect(flash[:error]).not_to be_empty }
    end
  end
end
