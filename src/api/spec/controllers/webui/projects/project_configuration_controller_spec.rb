require 'ostruct' # for OpenStruct

RSpec.describe Webui::Projects::ProjectConfigurationController, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:apache_project) { create(:project, name: 'Apache') }
  let(:another_project) { create(:project, name: 'Another_Project') }

  describe 'show' do
    before do
      login user
    end

    context 'Can load project config' do
      before do
        allow(ProjectConfigurationService::ProjectConfigurationPresenter).to receive(:new) {
          -> { OpenStruct.new(valid?: true, config: '') }
        }
      end

      it { expect { get :show, params: { project_name: apache_project.name } }.not_to raise_error }
    end

    context 'Can not load project config' do
      before do
        allow(ProjectConfigurationService::ProjectConfigurationPresenter).to receive(:new) {
          -> { OpenStruct.new(valid?: false, errors: 'yada yada') }
        }
      end

      it { expect { get :show, params: { project_name: apache_project.name } }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe 'update' do
    before do
      login user
    end

    context 'can save a project config' do
      before do
        allow(ProjectConfigurationService::ProjectConfigurationUpdater).to receive(:new) {
          -> { OpenStruct.new(saved?: true) }
        }
        post :update, params: { project_name: user.home_project.name, config: 'save config' }
      end

      it { expect(flash[:success]).to eq('Config successfully saved!') }
      it { expect(response).to have_http_status(:ok) }
    end

    context 'cannot save a project config' do
      before do
        allow(ProjectConfigurationService::ProjectConfigurationUpdater).to receive(:new) {
          -> { OpenStruct.new(saved?: false, errors: 'yay') }
        }
        post :update, params: { project_name: user.home_project.name, config: '' }
      end

      it { expect(flash[:error]).not_to be_nil }
      it { expect(response).to have_http_status(:bad_request) }
    end

    context 'cannot save with an unauthorized user' do
      before do
        post :update, params: { project_name: another_project.name, config: 'save config' }
      end

      it { expect(flash[:error]).to eq('Sorry, you are not authorized to update this project.') }
      it { expect(response).to have_http_status(:found) }
      it { expect(response).to redirect_to(root_path) }
    end
  end
end
