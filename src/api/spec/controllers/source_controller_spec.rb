require 'rails_helper'
# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe SourceController, vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }

  describe 'POST #global_command_orderkiwirepos' do
    it 'is accessible anonymously and forwards backend errors' do
      post :global_command_orderkiwirepos, params: { cmd: 'orderkiwirepos' }
      expect(response).to have_http_status(:bad_request)
      expect(Xmlhash.parse(response.body)['summary']).to eq('read_file: no content attached')
    end
  end

  describe 'POST #global_command_branch' do
    it 'is not accessible anonymously' do
      post :global_command_branch, params: { cmd: 'branch' }
      expect(flash[:error]).to eq('Anonymous user is not allowed here - please login (anonymous_user)')
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST #global_command_createmaintenanceincident' do
    it 'is not accessible anonymously' do
      post :global_command_createmaintenanceincident, params: { cmd: 'createmaintenanceincident' }
      expect(flash[:error]).to eq('Anonymous user is not allowed here - please login (anonymous_user)')
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST #package_command' do
    let(:multibuild_package) { create(:package, name: 'multibuild') }
    let(:multibuild_project) { multibuild_package.project }
    let(:repository) { create(:repository) }
    let(:target_repository) { create(:repository) }

    before do
      multibuild_project.repositories << repository
      project.repositories << target_repository
      login user
    end

    context "with 'diff' command for a multibuild package" do
      before do
        post :package_command, params: {
          cmd: 'diff', package: "#{multibuild_package.name}:one", project: multibuild_project, target_project: project
        }
      end

      it { expect(flash[:error]).to eq("invalid package name '#{multibuild_package.name}:one' (invalid_package_name)") }
      it { expect(response.status).to eq(302) }
    end
  end

  describe 'POST #package_command_undelete' do
    context 'when not having permissions on the deleted package' do
      let(:package) { create(:package) }

      before do
        package.destroy
        login user

        post :package_command, params: {
          cmd: 'undelete', project: package.project, package: package
        }
      end

      it { expect(response.status).to eq(302) }
      it { expect(flash[:error]).to have_text('no permission to create package') }
    end

    context 'when having permissions on the deleted package' do
      let(:package) { create(:package, name: 'some_package', project: project) }

      before do
        package.destroy
        login user

        post :package_command, params: {
          cmd: 'undelete', project: package.project, package: package
        }
      end

      it { expect(response.status).to eq(200) }
    end

    context 'when not having permissions to set the time' do
      let(:package) { create(:package, project: project) }

      before do
        package.destroy
        login user

        post :package_command, params: {
          cmd: 'undelete', project: package.project, package: package, time: 1.month.ago
        }
      end

      it { expect(response.status).to eq(302) }
      it { expect(flash[:error]).to have_text('Only administrators are allowed to set the time') }
    end

    context 'when having permissions to set the time' do
      let(:admin) { create(:admin_user, login: 'admin') }
      let(:package) { create(:package, name: 'some_package', project: project) }
      let(:future) { 4_803_029_439 }

      before do
        package.destroy
        login admin

        post :package_command, params: {
          cmd: 'undelete', project: package.project, package: package, time: future
        }
      end

      it { expect(response.status).to eq(200) }
    end
  end
end
