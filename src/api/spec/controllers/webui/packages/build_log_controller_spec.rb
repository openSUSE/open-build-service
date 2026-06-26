require 'webmock/rspec'
RSpec.describe Webui::Packages::BuildLogController do
  let(:project) { create(:project, name: 'my_project') }
  let(:repository) { create(:repository, name: 'my_repository', project: project, architectures: ['x86_64']) }
  let(:package) { create(:package, name: 'my_package', project: project) }
  let(:build_result) { file_fixture('build_result.xml').read }

  describe 'GET #live_build_log' do
    context 'success' do
      before do
        allow(Package).to receive(:what_depends_on).and_return([])
        allow(Backend::Api::BuildResults::Status).to receive(:build_result).and_return(build_result)
        get :live_build_log, params: { project: project, package: package, repository: repository, arch: 'x86_64', format: 'js' }
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context 'with a sourceaccess protected project' do
      let(:project) do
        project = create(:project, name: 'my_project')
        create(:sourceaccess_flag, project: project)
        project.reload
      end
      let(:user) { create(:confirmed_user) }

      before do
        allow(Backend::Api::BuildResults::Status).to receive(:build_result).and_return(build_result)
        allow(Package).to receive(:what_depends_on).and_return([])
        login user
        get :live_build_log, params: { project: project, package: package, repository: repository, arch: 'x86_64', format: 'js' }
      end

      it { expect(flash[:error]).to eq('Package not found: my_project/my_package') }
    end
  end
end
