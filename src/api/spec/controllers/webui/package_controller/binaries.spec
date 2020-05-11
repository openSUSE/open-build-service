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

  describe 'GET #binaries' do
    before do
      login tom
    end

    context 'with a failure in the backend' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_raise(Backend::Error, 'fake message')
        get :binaries, params: { package: toms_package, project: home_tom, repository: repo_for_home_tom.name }
      end

      it { expect(flash[:error]).to eq('fake message') }
      it { expect(response).to redirect_to(package_show_path(project: home_tom, package: toms_package)) }
    end

    context 'without build results' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_raise(Backend::NotFoundError)
      end

      let(:get_binaries) { get :binaries, params: { package: toms_package, project: home_tom, repository: repo_for_home_tom.name } }

      it { expect { get_binaries }.to raise_error(ActiveRecord::RecordNotFound) }
    end
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

    context 'when wiping binaries succeeds', vcr: true do
      let!(:repository) { create(:repository, name: 'my_repository', project: home_tom, architectures: ['i586']) }

      before do
        home_tom.store

        post :wipe_binaries, params: { project: home_tom, package: toms_package, repository: repository.name }
      end

      it { expect(flash[:success]).to eq("Triggered wipe binaries for #{home_tom.name}/#{toms_package.name} successfully.") }
      it { expect(response).to redirect_to(package_binaries_path(project: home_tom, package: toms_package, repository: repository.name)) }
    end
  end

  describe 'GET #binary' do
    let(:architecture) { 'x86_64' }
    let(:package_binaries_page) { package_binaries_path(package: toms_package, project: home_tom, repository: repo_for_home_tom.name) }
    let(:fake_fileinfo) { { sumary: 'fileinfo', description: 'fake' } }

    before do
      login(tom)
    end

    context 'with a failure in the backend' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo_ext).and_raise(Backend::Error, 'fake message')
      end

      subject do
        get :binary, params: { package: toms_package,
                               project: home_tom,
                               repository: repo_for_home_tom.name,
                               arch: 'x86_64',
                               filename: 'filename.txt' }
      end

      it { expect(response).to have_http_status(:success) }

      it 'shows an error message' do
        subject
        expect(flash[:error]).to eq('There has been an internal error. Please try again.')
      end
    end

    context 'without file info' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo_ext).and_return(nil)
      end

      subject do
        get :binary, params: { package: toms_package,
                               project: home_tom,
                               repository: repo_for_home_tom.name,
                               arch: 'x86_64',
                               filename: 'filename.txt' }
      end

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'without a valid architecture' do
      before do
        get :binary, params: { package: toms_package, project: home_tom, repository: repo_for_home_tom.name, arch: 'fake_arch', filename: 'filename.txt' }
      end

      it { expect(flash[:error]).to eq("Couldn't find architecture 'fake_arch'") }
      it { is_expected.to redirect_to(package_binaries_page) }
    end

    context 'with a valid download url' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo_ext).and_return(fake_fileinfo)
        allow_any_instance_of(::PackageControllerService::URLGenerator).to receive(:download_url_for_file_in_repo).and_return('http://fake.com/filename.txt')
      end

      context 'and normal html request' do
        before do
          get :binary, params: { package: toms_package, project: home_tom, repository: repo_for_home_tom.name, arch: 'x86_64', filename: 'filename.txt', format: :html }
        end

        it { expect(response).to have_http_status(:success) }
      end

      context 'and a non html request' do
        before do
          get :binary, params: { package: toms_package, project: home_tom, repository: repo_for_home_tom.name, arch: 'x86_64', filename: 'filename.txt' }
        end

        it { expect(response).to have_http_status(:redirect) }
        it { is_expected.to redirect_to('http://fake.com/filename.txt') }
      end
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

  describe 'GET #binary_download' do
    before do
      login(tom)
    end

    context 'when the backend has a build result', vcr: true do
      subject do
        get :binary_download, params: { package: toms_package, project: home_tom, repository: repo_for_home_tom.name, arch: 'i586', filename: 'my_file' }
      end

      it { is_expected.to redirect_to('http://localhost:3203/build/home:tom/source_repo/i586/my_package/my_file') }
    end

    context 'when requesting a result for an invalid repository' do
      subject! do
        get :binary_download, params: { package: toms_package, project: home_tom, repository: 'invalid', arch: 'i586', filename: 'my_file' }
      end

      it { is_expected.to redirect_to(package_show_path(project: home_tom, package: toms_package)) }
      it { expect(flash[:error]).to eq("Couldn't find repository 'invalid'") }
    end

    context 'when requesting a result for an invalid architecture' do
      subject! do
        get :binary_download, params: { package: toms_package, project: home_tom, repository: repo_for_home_tom.name, arch: 'invalid', filename: 'my_file' }
      end

      it { is_expected.to redirect_to(package_binaries_path(project: home_tom, package: toms_package, repository: repo_for_home_tom.name)) }
      it { expect(flash[:error]).to eq("Couldn't find architecture 'invalid'") }
    end
  end
end
