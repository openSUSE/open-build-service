require 'webmock/rspec'

RSpec.describe Webui::Packages::BinariesController, :vcr do
  let(:tom) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_tom) { tom.home_project }
  let(:toms_package) { create(:package, name: 'my_package', project: home_tom) }
  let(:repo_for_home_tom) { create(:repository, project: home_tom, architectures: ['i586'], name: 'source_repo') }

  before do
    login(tom)
  end

  describe 'DELETE destroy' do
    context 'when wiping binaries fails' do
      before do
        allow(Backend::Api::Build::Project).to receive(:wipe_binaries).and_raise(Backend::Error, 'fake message')
        delete :destroy, params: { project_name: home_tom, package_name: toms_package, repository_name: repo_for_home_tom.name, format: :json }
      end

      it 'lets the user know there was an error' do
        expect(flash[:error]).to match('fake message')
      end
    end

    context 'when wiping binaries succeeds' do
      before do
        delete :destroy, params: { project_name: home_tom, package_name: toms_package, repository_name: repo_for_home_tom.name, format: :json }
      end

      it do
        expect(response).to redirect_to(project_package_repository_binaries_path(project_name: home_tom, package_name: toms_package,
                                                                                 repository_name: repo_for_home_tom.name))
      end
    end
  end
end
