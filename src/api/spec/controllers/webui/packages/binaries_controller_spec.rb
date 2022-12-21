require 'webmock/rspec'
require 'rails_helper'
RSpec.describe Webui::Packages::BinariesController, :vcr do
  let(:tom) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_tom) { tom.home_project }
  let(:toms_package) { create(:package, name: 'my_package', project: home_tom) }
  let(:repo_for_home_tom) do
    repo = create(:repository, project: home_tom, architectures: ['i586'], name: 'source_repo')
    home_tom.store(login: tom)
    repo
  end

  describe 'GET #index' do
    before do
      login tom
    end

    context 'with a failure in the backend' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_raise(Backend::Error, 'fake message')
        get :index, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom }
      end

      it { expect(flash[:error]).to eq('There has been an internal error. Please try again.') }
      it { expect(response).to redirect_to(root_path) }
    end

    context 'without build results' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_raise(Backend::NotFoundError)
      end

      let(:get_binaries) { get :index, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom } }

      it { expect { get_binaries }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe 'DELETE #destroy' do
    before do
      login tom
    end

    context 'when wiping binaries fails' do
      before do
        delete :destroy, params: { project_name: home_tom, package_name: toms_package, repository_name: 'non_existant_repository' }
      end

      it 'lets the user know there was an error' do
        expect(flash[:error]).to match('Error while triggering wipe binaries for home:tom/my_package')
        expect(flash[:error]).to match('no repository defined')
      end

      it 'redirects to package binaries' do
        expect(response).to redirect_to(project_package_repository_binaries_path(project_name: home_tom, package_name: toms_package))
      end
    end

    context 'when wiping binaries succeeds' do
      let!(:repository) { create(:repository, name: 'my_repository', project: home_tom, architectures: ['i586']) }

      before do
        home_tom.store

        delete :destroy, params: { project_name: home_tom, package_name: toms_package, repository_name: repository }
      end

      it { expect(flash[:success]).to eq("Triggered wipe binaries for #{home_tom.name}/#{toms_package.name} successfully.") }
      it { expect(response).to redirect_to(project_package_repository_binaries_path(project_name: home_tom, package_name: toms_package)) }
    end
  end

  describe 'GET #show' do
    let(:architecture) { 'x86_64' }
    let(:package_binaries_page) { project_package_repository_binaries_path(package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom) }
    let(:fake_fileinfo) { { sumary: 'fileinfo', description: 'fake' } }

    before do
      login tom
    end

    context 'with a failure in the backend' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo_ext).and_raise(Backend::Error, 'fake message')
      end

      subject do
        get :show, params: { package_name: toms_package,
                             project_name: home_tom,
                             repository_name: repo_for_home_tom,
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
        get :show, params: { package_name: toms_package,
                             project_name: home_tom,
                             repository_name: repo_for_home_tom,
                             arch: 'x86_64',
                             filename: 'filename.txt' }
      end

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'without a valid architecture' do
      before do
        get :show, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom, arch: 'fake_arch', filename: 'filename.txt' }
      end

      it { expect(flash[:error]).to eq("Couldn't find architecture 'fake_arch'.") }
      it { is_expected.to redirect_to(package_binaries_page) }
    end

    context 'with a valid download url' do
      before do
        # We want to use the backend path here
        allow(Backend::Api::BuildResults::Binaries).to receive_messages(fileinfo_ext: fake_fileinfo, download_url_for_file: nil)
      end

      context 'and normal html request' do
        before do
          get :show, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom, arch: 'x86_64', filename: 'filename.txt', format: :html }
        end

        it { expect(response).to have_http_status(:success) }
      end

      context 'and a non html request' do
        before do
          get :show, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom, arch: 'x86_64', filename: 'filename.txt' }
        end

        it { expect(response).to have_http_status(:redirect) }
        it { is_expected.to redirect_to('http://test.host/build/home:tom/source_repo/x86_64/my_package/filename.txt') }
      end
    end
  end

  describe 'GET #dependency' do
    before do
      login tom
      allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo_ext).and_return(fileinfo)

      get 'dependency', params: { project_name: home_tom, package_name: toms_package, binary_filename: 'test.rpm' }.merge(params)
    end

    let(:fileinfo) { { summary: 'fileinfo', description: 'fake' } }

    context 'when passing params referring to an invalid project' do
      let(:params) { { repository_name: repo_for_home_tom, arch: 'i586', dependant_project: 'project' } }

      it { expect(flash[:error]).to eq("Project '#{params[:dependant_project]}' is invalid.") }
      it { expect(response).to have_http_status(:redirect) }
    end

    context 'when passing params referring to a valid project and an invalid architecture' do
      let(:params) { { repository_name: repo_for_home_tom, dependant_project: home_tom.name, arch: '123' } }

      it { expect(flash[:error]).to eq("Couldn't find architecture '#{params[:arch]}'.") }
      it { expect(response).to have_http_status(:redirect) }
    end

    context 'when passing params referring to valid project/architecture and an invalid repository' do
      let(:params) { { dependant_project: home_tom.name, arch: 'i586', repository_name: 'something' } }

      it { expect(flash[:error]).to eq("Couldn't find repository '#{params[:repository_name]}'.") }
      it { expect(response).to have_http_status(:redirect) }
    end

    context 'when passing params referring to valid project/architecture/repository and an invalid repository' do
      let(:params) do
        {
          dependant_project: home_tom,
          arch: 'i586',
          repository_name: repo_for_home_tom,
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
          repository_name: repo_for_home_tom,
          dependant_repository: another_repo_for_home_tom.name
        }
      end

      it { expect(assigns(:dependant_repository)).to eq(params[:dependant_repository]) }
      it { expect(assigns(:dependant_project)).to eq(params[:dependant_project]) }
      it { expect(response).to have_http_status(:success) }

      context 'and fileinfo is nil' do
        let(:fileinfo) { nil }

        it { expect(response).to have_http_status(:redirect) }
      end
    end
  end
end
