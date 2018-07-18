require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Services::WebhooksController, type: :controller, vcr: true do
  describe '#create' do
    let(:user) { create(:confirmed_user, login: 'tom') }
    let(:service_token) { create(:service_token, user: user) }
    let(:body) { { hello: :world }.to_json }
    let(:project) { user.home_project }
    let(:package) { create(:package_with_service, name: 'apache2', project: project) }
    let(:signature) { 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), service_token.string, body) }

    shared_examples 'it verifies the signature' do
      before do
        request.headers[signature_header_name] = signature
      end

      context 'when signature is valid' do
        let(:path) { "#{CONFIG['source_url']}/source/#{project.name}/#{package.name}?cmd=runservice&user=#{user.login}" }

        before do
          stub_request(:get, path).and_return(body: 'does not matter')
          post :create, body: body, params: { id: service_token.id, project: project.name, package: package.name, format: :xml }
        end

        it { expect(response).to be_success }
      end

      context 'when token is invalid' do
        it 'renders an error with an invalid signature' do
          request.headers[signature_header_name] = 'sha1=invalid'
          post :create, body: body, params: { id: service_token.id, project: project.name, package: package.name, format: :xml }
          expect(response).to be_forbidden
        end

        it 'renders an error with an invalid token' do
          invalid_token_id = 42
          post :create, body: body, params: { id: invalid_token_id, project: project.name, package: package.name, format: :xml }
          expect(response).to be_forbidden
        end
      end

      context 'when user has no permissions' do
        let(:project_without_permissions) { create(:project, name: 'Apache') }
        let(:package_without_permissions) { create(:package_with_service, name: 'apache2', project: project_without_permissions) }
        let(:inactive_user) { create(:user) }
        let(:invalid_service_token) { create(:service_token, user: inactive_user) }

        it 'renders an error for missing package permissions' do
          params = { id: service_token.id, project: project_without_permissions.name, package: package_without_permissions.name, format: :xml }
          post :create, body: body, params: params
          expect(response).to be_not_found
        end

        it 'renders an error for an inactive user' do
          signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), invalid_service_token.string, body)
          request.headers[signature_header_name] = signature
          params = { id: invalid_service_token.id, project: project.name, package: package.name, format: :xml }
          post :create, body: body, params: params
          expect(response).to be_not_found
        end
      end

      context 'when entity does not exist' do
        it 'renders an error for package' do
          params = { id: service_token.id, project: project.name, package: 'does-not-exist', format: :xml }
          post :create, body: body, params: params
          expect(response).to be_not_found
        end

        it 'renders an error for project' do
          params = { id: service_token.id, project: 'does-not-exist', package: package.name, format: :xml }
          post :create, body: body, params: params
          expect(response).to be_not_found
        end
      end
    end

    context 'with HTTP_X_OBS_SIGNATURE http header' do
      let(:signature_header_name) { 'HTTP_X_OBS_SIGNATURE' }

      it_behaves_like 'it verifies the signature'
    end

    context 'with HTTP_X_HUB_SIGNATURE http header' do
      let(:signature_header_name) { 'HTTP_X_HUB_SIGNATURE' }

      it_behaves_like 'it verifies the signature'
    end

    context 'with HTTP_X-Pagure-Signature-256 http header' do
      let(:signature_header_name) { 'HTTP_X-Pagure-Signature-256' }

      it_behaves_like 'it verifies the signature'
    end
  end
end
