RSpec.describe Webui::Packages::TriggerController, :vcr do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { create(:project_with_repository, name: 'my_project', maintainer: user) }

  before do
    login(user)
  end

  describe 'POST #services' do
    let(:package) { create(:package_with_service, name: 'my_service_package', project: project) }

    before do
      post :services, params: { project_name: project, package_name: package }
    end

    it { expect(flash[:success]).to eq('Services successfully triggered') }

    context 'when triggering services fails' do
      let(:package) { create(:package, name: 'my_package', project: project) }

      it { expect(flash[:error]).to eq('Error while triggering services for my_project/my_package: no source service defined!') }
    end
  end

  describe 'POST #rebuild' do
    let(:package) { create(:package_with_file, name: 'my_package', project: project) }

    before do
      post :rebuild, params: { project_name: project, package_name: package }
    end

    it { expect(flash[:success]).to eq('Rebuild successfully triggered') }

    context 'when triggering a rebuild fails' do
      let(:project) { create(:project, name: 'my_project', maintainer: user) }

      it { expect(flash[:error]).to eq('Error while triggering rebuild for my_project/my_package: no repository defined') }
    end
  end

  describe 'POST #abort_build' do
    let(:package) { create(:package_with_file, name: 'my_package', project: project) }

    before do
      post :abort_build, params: { project_name: project, package_name: package }
    end

    it { expect(flash[:success]).to eq('Abort build successfully triggered') }

    context 'when triggering abort build fails' do
      let(:project) { create(:project, name: 'my_project', maintainer: user) }

      it { expect(flash[:error]).to eq('Error while triggering abort build for my_project/my_package: no repository defined') }
    end
  end
end
