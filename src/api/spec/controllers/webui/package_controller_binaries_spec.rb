require 'webmock/rspec'
require 'rails_helper'
RSpec.describe Webui::PackageController do
  let(:tom) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_tom) { tom.home_project }
  let(:toms_package) { create(:package, name: 'my_package', project: home_tom) }
  let(:repo_for_home_tom) do
    repo = create(:repository, project: home_tom, architectures: ['i586'], name: 'source_repo')
    home_tom.store(login: tom)
    repo
  end

  describe 'POST #wipe_binaries' do
    before do
      login(tom)
    end

    context 'when wiping binaries fails' do
      before do
        post :wipe_binaries, params: { project: home_tom, package: toms_package, repository: 'non_existant_repository' }
      end

      it 'lets the user know there was an error' do
        expect(flash[:error]).to match('Error while triggering wipe binaries for home:tom/my_package')
        expect(flash[:error]).to match('no repository defined')
      end

      it 'redirects to package binaries' do
        expect(response).to redirect_to(package_binaries_path(project: home_tom, package: toms_package,
                                                              repository: 'non_existant_repository'))
      end
    end

    context 'when wiping binaries succeeds', :vcr do
      let!(:repository) { create(:repository, name: 'my_repository', project: home_tom, architectures: ['i586']) }

      before do
        home_tom.store

        post :wipe_binaries, params: { project: home_tom, package: toms_package, repository: repository.name }
      end

      it { expect(flash[:success]).to eq("Triggered wipe binaries for #{home_tom.name}/#{toms_package.name} successfully.") }
      it { expect(response).to redirect_to(package_binaries_path(project: home_tom, package: toms_package, repository: repository.name)) }
    end
  end

  describe 'GET #dependency' do
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
      let(:params) do
        {
          dependant_project: home_tom.name,
          arch: 'i586',
          repository: repo_for_home_tom.name,
          dependant_repository: 'something'
        }
      end

      it { expect(flash[:error]).to eq("Repository '#{params[:dependant_repository]}' is invalid.") }
      it { expect(response).to have_http_status(:redirect) }
    end

    context 'when passing params referring to valid project/architecture/repositories and a filename' do
      let(:another_repo_for_home_tom) do
        create(:repository, project: home_tom, architectures: ['i586'], name: 'source_repo_2').tap { |_| home_tom.store }
      end

      let(:params) do
        {
          dependant_project: home_tom.name,
          arch: 'i586',
          repository: repo_for_home_tom.name,
          dependant_repository: another_repo_for_home_tom.name,
          filename: 'test.rpm'
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
