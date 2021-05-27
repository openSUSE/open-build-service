require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TriggerController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'foo') }
  let(:project) { create(:project, name: 'project', maintainer: user) }
  let(:package) { create(:package, name: 'package_trigger', project: project) }
  let(:repository) { create(:repository, name: 'package_test_repository', architectures: ['x86_64'], project: project) }

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

    context 'when token is valid' do
      let!(:token) { Token::Rebuild.create(user: user, package: package) }

      before do
        allow(Backend::Api::Sources::Package).to receive(:rebuild).and_return("<status code=\"ok\" />\n")

        post :create, params: { format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
    end
  end

  describe '#release' do
    let(:target_project) { create(:project, name: 'target_project', maintainer: user) }
    let(:target_repository) { create(:repository, name: 'target_repository', project: target_project) }
    let(:release_target) { create(:release_target, repository: repository, target_repository: target_repository, trigger: 'manual') }

    context 'for inexistent project' do
      let(:token) { Token::Release.create(user: user, package: package) }

      before do
        post :create, params: { project: 'foo', format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'when token is valid and package exists' do
      let(:token) { Token::Release.create(user: user, package: package) }

      let(:backend_url) do
        "/build/#{target_project.name}/#{target_repository.name}/x86_64/#{package.name}" \
          "?cmd=copy&oproject=#{CGI.escape(project.name)}&opackage=#{package.name}&orepository=#{repository.name}" \
          '&resign=1&multibuild=1'
      end

      before do
        release_target
        allow(Backend::Connection).to receive(:post).and_call_original
        allow(Backend::Connection).to receive(:post).with(backend_url).and_return("<status code=\"ok\" />\n")
        post :create, params: { package: package, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'when user has no rights for source' do
      let(:other_user) { create(:confirmed_user, login: 'mrfluffy') }
      let(:token) { Token::Release.create(user: other_user, package: package) }

      before do
        release_target
        post :create, params: { package: package, format: :xml }
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'when user has no rights for target' do
      let(:other_user) { create(:confirmed_user, login: 'mrfluffy') }
      let(:token) { Token::Release.create(user: other_user, package: package) }
      let!(:relationship_package_user) { create(:relationship_package_user, user: other_user, package: package) }

      before do
        release_target
        post :create, params: { package: package, format: :xml }
      end

      it { expect(response).to have_http_status(:forbidden) }
      it { expect(response.body).to include("No permission to modify project 'target_project' for user 'mrfluffy'") }
    end

    context 'when there are no release targets' do
      let(:other_user) { create(:confirmed_user, login: 'mrfluffy') }
      let(:token) { Token::Release.create(user: other_user, package: package) }
      let!(:relationship_package_user) { create(:relationship_package_user, user: other_user, package: package) }

      before do
        post :create, params: { package: package, format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe '#runservice' do
    let(:token) { Token::Service.create(user: user, package: package) }
    let(:package) { create(:package_with_service, name: 'package_with_service', project: project) }

    before do
      post :create, params: { package: package, format: :xml }
    end

    it { expect(response).to have_http_status(:success) }
  end

  describe '#create' do
    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
    let(:service_token) { create(:service_token, user: user) }
    let(:body) { { hello: :world }.to_json }
    let(:project) { user.home_project }
    let(:package) { create(:package_with_service, name: 'apache2', project: project) }
    let(:token) { Token::Service.create(user: user, package: package) }
    let(:signature) { 'sha256=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), service_token.string, body) }

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
        let(:token) { nil }

        it 'renders an error with an invalid signature' do
          request.headers[signature_header_name] = 'sha256=invalid'
          post :create, body: body, params: { project: project.name, package: package.name, format: :xml }
          expect(response).to have_http_status(:forbidden)
        end

        it 'renders an error with an invalid token' do
          post :create, body: body, params: { project: project.name, package: package.name, format: :xml }
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with HTTP_X_OBS_SIGNATURE http header' do
      let(:signature_header_name) { 'HTTP_X_OBS_SIGNATURE' }

      it_behaves_like 'it verifies the signature'
    end

    context 'with HTTP_X_HUB_SIGNATURE_256 http header' do
      let(:signature_header_name) { 'HTTP_X_HUB_SIGNATURE_256' }

      it_behaves_like 'it verifies the signature'
    end

    context 'with HTTP_X-Pagure-Signature-256 http header' do
      let(:signature_header_name) { 'HTTP_X-Pagure-Signature-256' }

      it_behaves_like 'it verifies the signature'
    end
  end

  describe '#set_project' do
    let(:token) { Token::Rebuild.create(user: user) }

    before { allow(Project).to receive(:get_by_name).and_return('some:remote:project') }

    it 'raises a not found for a remote project' do
      params = { project: 'some:remote:project', package: package.name, format: :xml }
      post :create, params: params
      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#set_package' do
    let(:token) { Token::Service.create(user: user) }

    it 'raises when package does not exist' do
      params = { project: project.name, package: 'does-not-exist', format: :xml }
      post :create, params: params
      expect(response).to have_http_status(:not_found)
    end

    context 'project with project-link and token that follows project-links' do
      let(:token) { Token::Rebuild.create(user: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: project) }

      it 'raises when package does not exist in link' do
        params = { project: project_with_a_link.name, package: 'does-not-exist', format: :xml }
        post :create, params: params
        expect(response).to have_http_status(:not_found)
      end

      it 'assigns linked package' do
        params = { project: project_with_a_link.name, package: package.name, format: :xml }
        post :create, params: params
        expect(assigns(:package)).to eq(package)
      end
    end

    context 'project with remote project-link' do
      let(:token) { Token::Rebuild.create(user: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: 'some:remote:project') }

      it 'assigns remote package string' do
        params = { project: project_with_a_link.name, package: 'remote_package_trigger', format: :xml }
        post :create, params: params
        expect(assigns(:package)).to eq('remote_package_trigger')
      end
    end
  end

  describe '#set_object_to_authorize' do
    let(:token) { Token::Service.create(user: user) }
    let(:local_package) { create(:package, name: 'local_package', project: project_with_a_link) }

    it 'assigns associated package' do
      params = { project: project.name, package: package.name, format: :xml }
      post :create, params: params
      expect(assigns(:token).object_to_authorize).to eq(package)
    end

    context 'project with project-link' do
      let(:token) { Token::Rebuild.create(user: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: project) }

      it 'authorizes the project if the package is from a project with a link' do
        params = { project: project_with_a_link.name, package: package.name, format: :xml }
        post :create, params: params
        expect(assigns(:token).object_to_authorize).to eq(project_with_a_link)
      end

      it 'authorizes the package if the package is local' do
        params = { project: project_with_a_link.name, package: local_package.name, format: :xml }
        post :create, params: params
        expect(assigns(:token).object_to_authorize).to eq(local_package)
      end
    end

    context 'project with remote project-link' do
      let(:token) { Token::Rebuild.create(user: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: 'some:remote:project') }

      it 'authorizes the project if the package is from a project with a link' do
        params = { project: project_with_a_link.name, package: 'some-remote-package-that-might-exist', format: :xml }
        post :create, params: params
        expect(assigns(:token).object_to_authorize).to eq(project_with_a_link)
      end

      it 'authorizes the package if the package is local' do
        params = { project: project_with_a_link.name, package: local_package.name, format: :xml }
        post :create, params: params
        expect(assigns(:token).object_to_authorize).to eq(local_package)
      end
    end
  end

  describe '#set_multibuild_flavor' do
    let(:multibuild_package) { create(:multibuild_package, name: 'package_a', project: project, flavors: ['libfoo1', 'libfoo2']) }
    let(:multibuild_flavor) { 'libfoo2' }

    context 'with a token that allows multibuild' do
      let(:token) { Token::Rebuild.create(user: user) }

      it 'assigns flavor name' do
        params = { project: project.name, package: "#{multibuild_package.name}:#{multibuild_flavor}", format: :xml }
        post :create, params: params
        expect(assigns(:multibuild_container)).to eq(multibuild_flavor)
      end

      it 'authorizes package object' do
        params = { project: project.name, package: "#{multibuild_package.name}:#{multibuild_flavor}", format: :xml }
        post :create, params: params
        expect(assigns(:token).object_to_authorize).to eq(multibuild_package)
      end
    end

    context 'with a token that does not allow multibuild' do
      let(:token) { Token::Service.create(user: user) }

      it 'raises not found' do
        params = { project: project.name, package: multibuild_flavor, format: :xml }
        post :create, params: params
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
