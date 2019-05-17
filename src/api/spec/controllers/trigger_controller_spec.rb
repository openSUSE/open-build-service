require 'rails_helper'

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
    allow(User).to receive(:session!).and_return(admin)
    allow(::TriggerControllerService::TokenExtractor).to receive(:new) {
      -> { OpenStruct.new(valid?: true, token: token) }
    }
    package
  end

  describe '#rebuild' do
    context 'authentication token is invalid' do
      before do
        allow(::TriggerControllerService::TokenExtractor).to receive(:new) {
          -> { OpenStruct.new(valid?: false, token: nil) }
        }
        post :rebuild, params: { format: :xml }
      end

      it { is_expected.to respond_with(:forbidden) }
    end

    context 'when token is valid and packet rebuild' do
      let(:token) { Token::Rebuild.create(user: admin, package: package) }

      before do
        allow(Backend::Api::Sources::Package).to receive(:rebuild).and_return("<status code=\"ok\" />\n")
        post :rebuild, params: { format: :xml }
      end

      it { is_expected.to respond_with(:success) }
    end
  end

  describe '#release' do
    context 'when project param is given' do
      before do
        post :release, params: { project: 'foo', format: :xml }
      end

      it { is_expected.to respond_with(:forbidden) }
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

      it { is_expected.to respond_with(:success) }
    end
  end

  describe '#runservice' do
    let(:token) { Token::Service.create(user: admin, package: package) }
    let(:project) { admin.home_project }
    let!(:package) { create(:package_with_service, name: 'package_with_service', project: project) }

    before do
      post :runservice, params: { package: package, format: :xml }
    end

    it { is_expected.to respond_with(:success) }
  end
end
