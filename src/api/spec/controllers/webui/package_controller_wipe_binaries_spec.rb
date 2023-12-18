require 'webmock/rspec'

RSpec.describe Webui::PackageController, :vcr do
  let(:tom) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_tom) { tom.home_project }
  let(:toms_package) { create(:package, name: 'my_package', project: home_tom) }
  let(:repo_for_home_tom) { create(:repository, project: home_tom, architectures: ['i586'], name: 'source_repo') }

  before do
    login(tom)
  end

  describe 'DELETE wipe_binaries' do
    context 'when wiping binaries fails' do
      before do
        delete :wipe_binaries, params: { project: home_tom, package: toms_package, repository: 'non_existant_repository', format: :json }
      end

      it 'lets the user know there was an error' do
        expect(flash[:error]).to match('Error while triggering wipe binaries for home:tom/my_package')
        expect(flash[:error]).to match('no repository defined')
      end

      it 'redirects to package binaries' do
        expect(response).to redirect_to(project_package_repository_binaries_path(project_name: home_tom, package_name: toms_package,
                                                                                 repository_name: 'non_existant_repository'))
      end
    end

    context 'when wiping binaries succeeds' do
      before do
        delete :wipe_binaries, params: { project: home_tom, package: toms_package, repository: repo_for_home_tom.name, format: :json }
      end

      it do
        expect(response).to redirect_to(project_package_repository_binaries_path(project_name: home_tom, package_name: toms_package,
                                                                                 repository_name: repo_for_home_tom.name))
      end
    end
  end
end
