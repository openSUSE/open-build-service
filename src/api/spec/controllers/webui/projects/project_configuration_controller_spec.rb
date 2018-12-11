require 'rails_helper'

RSpec.describe Webui::Projects::ProjectConfigurationController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:apache_project) { create(:project, name: 'Apache') }
  let(:another_project) { create(:project, name: 'Another_Project') }

  describe 'show' do
    before do
      login user
    end

    context 'Can load project config' do
      before do
        get :show, params: { project: apache_project }
      end

      it { expect(flash[:error]).to eq(nil) }
      it { expect(response).not_to redirect_to(projects_path(nextstatus: 404)) }
    end

    context 'Can not load project config' do
      before do
        allow_any_instance_of(ProjectConfigFile).to receive(:content).and_return(nil)
        get :show, params: { project: apache_project }
      end

      it { expect(flash[:error]).not_to eq(nil) }
      it { expect(response).to redirect_to(projects_path(nextstatus: 404)) }
    end
  end

  describe 'update' do
    before do
      login user
    end

    context 'can save a project config' do
      before do
        post :update, params: { project: user.home_project.name, config: 'save config' }
      end

      it { expect(flash[:success]).to eq('Config successfully saved!') }
      it { expect(response.status).to eq(200) }
    end

    context 'cannot save a project config' do
      before do
        allow_any_instance_of(ProjectConfigFile).to receive(:save).and_return(nil)
        post :update, params: { project: user.home_project.name, config: '' }
      end

      it { expect(flash[:error]).not_to be_nil }
      it { expect(response.status).to eq(400) }
    end

    context 'cannot save with an unauthorized user' do
      before do
        post :update, params: { project: another_project.name, config: 'save config' }
      end

      it { expect(flash[:error]).to eq('Sorry, you are not authorized to update this Project.') }
      it { expect(response.status).to eq(302) }
      it { expect(response).to redirect_to(root_path) }
    end

    context 'with a non existing project' do
      let(:post_update) { post :update, params: { project: 'non:existing:project', config: 'save config' } }

      it 'raise a RecordNotFound Exception' do
        expect { post_update }.to raise_error ActiveRecord::RecordNotFound
      end
    end
  end
end
