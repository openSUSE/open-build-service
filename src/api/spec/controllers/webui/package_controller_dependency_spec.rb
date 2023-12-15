require 'webmock/rspec'

RSpec.describe Webui::PackageController, :vcr do
  let(:tom) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_tom) { tom.home_project }
  let(:toms_package) { create(:package, name: 'my_package', project: home_tom) }
  let(:repo_for_home_tom) { create(:repository, project: home_tom, architectures: ['i586'], name: 'source_repo') }

  before do
    login(tom)
  end

  describe 'GET dependency' do
    before do
      allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo_ext).and_return(fileinfo)

      get :dependency, params: { project: home_tom, package: toms_package }.merge(params)
    end

    let(:fileinfo) { { summary: 'fileinfo', description: 'fake' } }

    context 'when passing params referring to an invalid project' do
      let(:params) { { dependant_project: 'project' } }

      it { expect(flash[:error]).to eq("Project '#{params[:dependant_project]}' is invalid.") }
      it { expect(response).to have_http_status(:redirect) }
    end

    context 'when passing params referring to a valid project and an invalid architecture' do
      let(:params) { { dependant_project: home_tom.name, arch: '123' } }

      it { expect(flash[:error]).to eq("Architecture '#{params[:arch]}' is invalid.") }
      it { expect(response).to have_http_status(:redirect) }
    end

    context 'when passing params referring to valid project/architecture and an invalid repository' do
      let(:params) { { dependant_project: home_tom.name, arch: 'i586', repository: 'something' } }

      it { expect(flash[:error]).to eq("Repository '#{params[:repository]}' is invalid.") }
      it { expect(response).to have_http_status(:redirect) }
    end

    context 'when passing params referring to valid project/architecture/repository and an invalid repository' do
      let(:params) { { dependant_project: home_tom.name, arch: 'i586', repository: repo_for_home_tom.name, dependant_repository: 'something' } }

      it { expect(flash[:error]).to eq("Repository '#{params[:dependant_repository]}' is invalid.") }
      it { expect(response).to have_http_status(:redirect) }
    end

    context 'when passing params referring to valid project/architecture/repositories and a filename' do
      let(:another_repo_for_home_tom) { create(:repository, project: home_tom, architectures: ['i586'], name: 'source_repo_2') }

      let(:params) do
        {
          dependant_project: home_tom.name, arch: 'i586', repository: repo_for_home_tom.name,
          dependant_repository: another_repo_for_home_tom.name, filename: 'test.rpm'
        }
      end

      it { expect(assigns(:arch)).to eq(params[:arch]) }
      it { expect(assigns(:repository)).to eq(params[:repository]) }
      it { expect(assigns(:dependant_repository)).to eq(params[:dependant_repository]) }
      it { expect(assigns(:dependant_project)).to eq(params[:dependant_project]) }
      it { expect(assigns(:filename)).to eq(params[:filename]) }
      it { expect(response).to have_http_status(:success) }

      context 'and fileinfo is nil' do
        let(:fileinfo) { nil }

        it { expect(response).to have_http_status(:redirect) }
      end
    end
  end
end
