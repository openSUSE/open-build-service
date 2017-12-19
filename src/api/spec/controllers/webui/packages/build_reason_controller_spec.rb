require 'rails_helper'
require 'webmock/rspec'
# WARNING: If you change owner tests make sure you uncomment this line
# and start a test backend. Some of the Owner methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::Packages::BuildReasonController, type: :controller, vcr: true do
  describe 'GET #index' do
    let(:user) { create(:confirmed_user, login: 'tom') }
    let(:source_project) { user.home_project }
    let(:package) { create(:package, name: 'package', project: source_project) }
    let(:repo_for_source_project) do
      repo = create(:repository, project: source_project, architectures: ['i586'])
      source_project.store
      repo
    end

    let(:valid_request_params) do
      {
        package_name: package.name,
        project:      source_project.name,
        repository:   repo_for_source_project.name,
        arch:         repo_for_source_project.architectures.first.name
      }
    end

    context 'without a valid respository' do
      before do
        get :index, params: { package_name: package, project: source_project, repository: 'fake_repo', arch: 'i586' }
      end

      it { expect(flash[:error]).not_to be_empty }
      it { expect(response).to redirect_to(package_binaries_path(package: package, project: source_project, repository: 'fake_repo')) }
    end

    context 'without a valid architecture' do
      before do
        login(user)
        get :index, params: { package_name: package, project: source_project, repository: repo_for_source_project.name, arch: 'i58' }
      end

      it { expect(flash[:error]).not_to be_empty }
      it 'should redirect to package_binaries_path' do
        expect(response).to redirect_to(package_binaries_path(package: package,
                                                              project: source_project, repository: repo_for_source_project.name))
      end
    end

    context 'for packages without a build reason' do
      before do
        path = "#{CONFIG['source_url']}/build/#{source_project.name}/#{repo_for_source_project.name}/" \
          "#{repo_for_source_project.architectures.first.name}/#{package.name}/_reason"
        stub_request(:get, path).and_return(body:
        %(<reason>\n <explain/>  <time/>  <oldsource/>  </reason>))

        get :index, params: valid_request_params
      end

      it { expect(flash[:notice]).not_to be_empty }
      it 'should redirect to package_binaries_path' do
        expect(response).to redirect_to(package_binaries_path(package: package,
                                                              project: source_project, repository: repo_for_source_project.name))
      end
    end

    context 'for valid requests' do
      before do
        path = "#{CONFIG['source_url']}/build/#{source_project.name}/#{repo_for_source_project.name}/" \
          "#{repo_for_source_project.architectures.first.name}/#{package.name}/_reason"
        stub_request(:get, path).and_return(body:
        %(<reason>\n  <explain>source change</explain>  <time>1496387771</time>  <oldsource>1de56fdc419ea4282e35bd388285d370</oldsource></reason>))

        get :index, params: valid_request_params
      end

      it 'responds with 200 OK' do
        expect(response).to have_http_status(:success)
      end

      it 'has build reason' do
        expect(assigns(:details)).to be_a(PackageBuildReason)
      end
    end
  end
end
