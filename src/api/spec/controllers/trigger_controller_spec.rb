require 'webmock/rspec'

RSpec.describe TriggerController do
  let(:user) { create(:confirmed_user, login: 'foo') }

  render_views

  before do
    token_extractor = instance_double(TriggerControllerService::TokenExtractor)
    allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor)
    allow(token_extractor).to receive(:call).and_return(token)
  end

  describe '#rebuild', :vcr do
    let(:token) { create(:rebuild_token, executor: user, package: nil) }
    let(:project) { create(:project_with_repository, name: 'project', maintainer: user) }
    let(:package) { create(:package, name: 'package_trigger', project: project) }

    context 'with token.package' do
      subject { post :rebuild, params: { format: :xml } }

      before do
        token.update!(package: package)
      end

      it { expect(subject).to have_http_status(:success) }
    end

    context 'with project and package parameter' do
      subject { post :rebuild, params: { project: project.name, package: package.name, format: :xml } }

      it { expect(subject).to have_http_status(:success) }
    end

    context 'with project parameter' do
      subject { post :rebuild, params: { project: project, format: :xml } }

      it { expect(subject).to have_http_status(:success) }
    end

    context 'token is not enabled' do
      subject { post :rebuild, params: { project: project.name, format: :xml } }

      let(:token) { create(:rebuild_token, enabled: false, executor: user) }

      it { expect(subject).to have_http_status(:forbidden) }
      it { expect(subject.body).to include('This token is not enabled.') }
    end
  end

  describe '#release', :vcr do
    let(:token) { create(:release_token, executor: user, package: nil) }
    let(:source_project) do
      project = create(:project, name: 'source_project', maintainer: user)
      repository = create(:repository, name: 'source_repository', project: project, architectures: ['x86_64'])
      create(:release_target, repository: repository, target_repository: target_project.repositories.first, trigger: 'manual')
      create(:package, name: 'source_package', project: project)

      project
    end
    let(:target_project) do
      project = create(:project, name: 'target_project', maintainer: user)
      create(:repository, name: 'target_repository', project: project, architectures: ['x86_64'])

      project
    end
    let(:source_package) { source_project.packages.first }
    let(:backend_url) do
      '/build/target_project/target_repository/x86_64/source_package' \
        '?cmd=copy&oproject=source_project&opackage=source_package&orepository=source_repository' \
        '&resign=1&multibuild=1'
    end

    # Mock the cmd=copy HTTP request. Mocking Token::Release/MaintenanceHelper is just too hard...
    before do
      allow(Backend::Connection).to receive(:post).and_call_original
      allow(Backend::Connection).to receive(:post).with(backend_url).and_return("<status code=\"ok\" />\n")
    end

    context 'with token.package' do
      subject { post :release, params: { format: :xml } }

      before do
        token.update!(package: source_package)
      end

      it { expect(subject).to have_http_status(:success) }
    end

    context 'with project and package parameter' do
      subject { post :release, params: { project: source_project.name, package: source_package.name, format: :xml } }

      it { expect(subject).to have_http_status(:success) }
    end

    context 'with project parameter' do
      subject { post :release, params: { project: source_project.name, format: :xml } }

      let(:backend_url) do
        '/build/target_project/target_repository/x86_64/source_package' \
          '?cmd=copy&oproject=source_project&orepository=source_repository' \
          '&resign=1&multibuild=1'
      end

      it { expect(subject).to have_http_status(:success) }
    end
  end

  describe '#runservice', :vcr do
    let(:token) { create(:service_token, executor: user, package: nil) }
    let(:project) { create(:project_with_repository, name: 'project', maintainer: user) }
    let(:package) { create(:package_with_service, name: 'package_with_service', project: project) }

    context 'with token.package' do
      subject { post :runservice, params: { format: :xml } }

      let(:token) { create(:service_token, executor: user, package: package) }

      it { expect(subject).to have_http_status(:success) }
    end

    context 'with project and package parameter' do
      subject { post :runservice, params: { project: project.name, package: package.name, format: :xml } }

      it { expect(subject).to have_http_status(:success) }
    end

    describe '.verfiy_package_params' do
      subject { post :runservice, params: { format: :xml, project: project } }

      it { expect(Xmlhash.parse(subject.body)['code']).to eq('missing_parameter') }
    end
  end

  describe '#create' do
    let(:token) { create(:rebuild_token, executor: user, package: nil) }
    let(:project) { create(:project_with_repository, name: 'project', maintainer: user) }
    let(:package) { create(:package, name: 'package_trigger', project: project) }

    context 'invalid token' do
      subject { post :create, params: { format: :xml } }

      let(:token) { nil }

      it { expect(Xmlhash.parse(subject.body)['code']).to eq('invalid_token') }
    end

    context 'workflow token' do
      subject { post :create, params: { format: :xml } }

      let(:token) { create(:workflow_token, executor: user) }

      it { expect(Xmlhash.parse(subject.body)['code']).to eq('invalid_token') }
    end
  end
end
