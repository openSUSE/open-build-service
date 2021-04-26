require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TriggerController, vcr: true do
  let(:admin) { create(:admin_user, :with_home, login: 'foo_admin') }
  let(:project) { admin.home_project }
  let(:package) { create(:package, name: 'package_trigger', project: project) }
  let(:repository) { create(:repository, name: 'package_test_repository', architectures: ['x86_64'], project: project) }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:target_repository) { create(:repository, name: 'target_repository', project: target_project) }
  let(:release_target) { create(:release_target, target_repository: target_repository, repository: repository, trigger: 'manual') }

  render_views

  before do
    # FIXME: fix the rubocop complain
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(::TriggerControllerService::TokenExtractor).to receive(:call).and_return(token)
    # rubocop:enable RSpec/AnyInstance
    package
  end

  describe '#rebuild' do
    context 'authentication token is invalid' do
      let!(:token) { nil }

      before do
        post :create, params: { format: :xml }
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'when token is valid and packet rebuild' do
      let!(:token) { Token::Rebuild.create(user: admin, package: package) }

      before do
        allow(Backend::Api::Sources::Package).to receive(:rebuild).and_return("<status code=\"ok\" />\n")
        post :create, params: { format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
    end
  end

  describe '#release' do
    context 'for inexistent project' do
      before do
        post :release, params: { project: 'foo', format: :xml }
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'when token is valid and package exists' do
      let(:token) { Token::Release.create(user: admin, package: package) }

      let(:backend_url) do
        "/build/#{target_project.name}/#{target_repository.name}/x86_64/#{package.name}" \
          "?cmd=copy&oproject=#{CGI.escape(project.name)}&opackage=#{package.name}&orepository=#{repository.name}" \
          '&resign=1&multibuild=1'
      end

      before do
        release_target
        allow(Backend::Connection).to receive(:post).and_call_original
        allow(Backend::Connection).to receive(:post).with(backend_url).and_return("<status code=\"ok\" />\n")
        post :release, params: { package: package, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'when user has no rights for source' do
      let(:user) { create(:confirmed_user, login: 'mrfluffy') }
      let(:token) { Token::Release.create(user: user, package: package) }

      before do
        allow(User).to receive(:session!).and_return(user)
        allow(::TriggerControllerService::TokenExtractor).to receive(:new) {
          -> { OpenStruct.new(valid?: true, token: token) }
        }
      end

      it { expect { post :release, params: { package: package, format: :xml } }.to raise_error.with_message(/no permission for package/) }
    end

    context 'when user has no rights for target' do
      let(:user) { create(:confirmed_user, login: 'mrfluffy') }
      let(:token) { Token::Release.create(user: user, package: package) }
      let!(:relationship_package_user) { create(:relationship_package_user, user: user, package: package) }

      before do
        release_target
        allow(User).to receive(:session!).and_return(user)
        allow(User).to receive(:possibly_nobody).and_return(user)
        allow(::TriggerControllerService::TokenExtractor).to receive(:new) {
          -> { OpenStruct.new(valid?: true, token: token) }
        }
        post :release, params: { package: package, format: :xml }
      end

      it { expect(response).to have_http_status(:forbidden) }
      it { expect(response.body).to include("No permission to modify project 'target_project' for user 'mrfluffy'") }
    end

    context 'when there are no release targets' do
      let(:user) { create(:confirmed_user, login: 'mrfluffy') }
      let(:token) { Token::Release.create(user: user, package: package) }
      let!(:relationship_package_user) { create(:relationship_package_user, user: user, package: package) }

      before do
        allow(User).to receive(:session!).and_return(user)
        allow(User).to receive(:possibly_nobody).and_return(user)
        allow(::TriggerControllerService::TokenExtractor).to receive(:new) {
          -> { OpenStruct.new(valid?: true, token: token) }
        }
      end

      it { expect { post :release, params: { package: package, format: :xml } }.to raise_error.with_message(/has no release targets that are triggered manually/) }
    end
  end

  describe '#runservice' do
    let(:token) { Token::Service.create(user: admin, package: package) }
    let(:project) { admin.home_project }
    let!(:package) { create(:package_with_service, name: 'package_with_service', project: project) }

    before do
      post :runservice, params: { package: package, format: :xml }
    end

    it { expect(response).to have_http_status(:success) }
  end

  describe '#create' do
    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
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

        it { expect(response).to have_http_status(:success) }
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
