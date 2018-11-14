require 'rails_helper'

RSpec.describe Webui::Staging::ProjectsController do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:managers_group) { create(:group) }
  let(:project) { user.home_project }
  let(:staging_workflow) { project.create_staging(managers: managers_group) }

  before do
    login(user)
  end

  describe 'POST #create' do
    context 'a staging_project' do
      before do
        post :create, params: { staging_workflow_id: staging_workflow.id, staging_project_name: 'C' }
      end

      subject { staging_workflow }

      it { expect(Project.count).to eq(4) }
      it 'create a new staging project' do
        subject.reload
        expect(subject.staging_projects.map(&:name)).to match_array(['home:tom:Staging:A', 'home:tom:Staging:B', 'home:tom:Staging:C'])
      end
      it { expect(response).to redirect_to(edit_staging_workflow_path(subject)) }
      it { expect(flash[:success]).not_to be_nil }
      it 'assigns the managers group' do
        expect(Staging::StagingProject.find_by_name('home:tom:Staging:C').groups.last).to eq(subject.managers_group)
      end
    end

    context 'an existent staging project' do
      before do
        post :create, params: { staging_workflow_id: staging_workflow.id, staging_project_name: 'A' }
      end

      subject { staging_workflow }

      it { expect(Project.count).to eq(3) }
      it { expect(subject.staging_projects.map(&:name)).to match_array(['home:tom:Staging:A', 'home:tom:Staging:B']) }
      it { expect(response).to redirect_to(edit_staging_workflow_path(subject)) }
      it { expect(flash[:error]).not_to be_nil }
    end

    context 'when it fails to save' do
      before do
        staging_workflow
        allow_any_instance_of(Project).to receive(:valid?).and_return(false)
        post :create, params: { staging_workflow_id: staging_workflow.id, staging_project_name: 'C' }
      end

      subject { staging_workflow }

      it { expect(Project.count).to eq(3) }
      it { expect(response).to redirect_to(edit_staging_workflow_path(subject)) }
      it { expect(flash[:error]).not_to be_nil }
    end
  end

  describe 'DELETE #destroy' do
    context 'non existent staging project' do
      before do
        delete :destroy, params: { staging_workflow_id: staging_workflow.id, project_name: 'fake_name' }
      end

      subject { staging_workflow }

      it { expect(response).to redirect_to(edit_staging_workflow_path(subject)) }
      it { expect(flash[:error]).not_to be_nil }
    end

    context 'with an existent staging_workflow for project' do
      let(:staging_project) { staging_workflow.staging_projects.first }

      before do
        delete :destroy, params: { staging_workflow_id: staging_workflow.id, project_name: staging_project.name }
      end

      subject { staging_workflow }

      it 'destroy a staging project' do
        subject.reload
        expect(subject.staging_projects.map(&:name)).to match_array(['home:tom:Staging:B'])
      end
      it { expect(assigns[:staging_workflow]).to eq(project.staging) }
      it { expect(response).to redirect_to(edit_staging_workflow_path(subject)) }
    end
  end
end
