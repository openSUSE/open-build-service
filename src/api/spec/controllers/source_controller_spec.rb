# frozen_string_literal: true

require 'rails_helper'
# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe SourceController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
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
      expect(flash[:error]).to eq('anonymous_user(Anonymous user is not allowed here - please login): ')
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST #global_command_createmaintenanceincident' do
    it 'is not accessible anonymously' do
      post :global_command_createmaintenanceincident, params: { cmd: 'createmaintenanceincident' }
      expect(flash[:error]).to eq('anonymous_user(Anonymous user is not allowed here - please login): ')
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'GET #show_project_meta' do
    before do
      login user
      get :show_project_meta, params: { project: project }
    end

    it { expect(response).to be_success }
    it { expect(Xmlhash.parse(response.body)['name']).to eq(project.name) }
  end

  describe 'PUT #update_project_config' do
    before do
      login user
      put :update_project_config, params: { project: project, comment: 'Updated by test' }
    end

    it { expect(response).to be_success }
    it { expect(project.config.to_s).to include('Updated', 'by', 'test') }
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
      it { expect(flash[:error]).to eq("invalid_package_name(invalid package name '#{multibuild_package.name}:one'): ") }
      it { expect(response.status).to eq(302) }
    end
  end
end
