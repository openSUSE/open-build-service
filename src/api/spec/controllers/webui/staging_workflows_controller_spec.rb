require 'rails_helper'

RSpec.describe Webui::StagingWorkflowsController do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }

  before do
    login(user)
  end

  describe 'GET #new' do
    context 'non existent staging_workflow for project' do
      before do
        get :new, params: { project: project.name }
      end

      it { expect(StagingWorkflow.count).to eq(0) }
      it { expect(assigns[:staging_workflow].class).to be(StagingWorkflow) }
      it { expect(response).to render_template(:new) }
    end

    context 'with an existent staging_workflow for project' do
      before do
        project.create_staging
        get :new, params: { project: project.name }
      end

      it { expect(StagingWorkflow.count).to eq(1) }
      it { expect(response).to redirect_to(staging_workflow_path(project.staging)) }
    end
  end

  describe 'POST #create' do
    context 'a staging_workflow and staging_projects' do
      before do
        post :create, params: { project: project.name }
      end

      subject { project.staging }

      it { expect(StagingWorkflow.count).to eq(1) }
      it { expect(subject.staging_projects.map(&:name)).to match_array(['home:tom:Staging:A', 'home:tom:Staging:B']) }
      it { expect(response).to redirect_to(staging_workflow_path(project.staging)) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'with existent stagings projects' do
      let!(:staging_a) { create(:project, name: "#{project}:Staging:A") }
      let!(:staging_b) { create(:project, name: "#{project}:Staging:B") }

      before do
        post :create, params: { project: project.name }
      end

      subject { project.staging }

      it { expect(StagingWorkflow.count).to eq(1) }
      it { expect(subject.staging_projects.map(&:name)).to match_array(['home:tom:Staging:A', 'home:tom:Staging:B']) }
      it { expect(response).to redirect_to(staging_workflow_path(project.staging)) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'when it fails to save' do
      before do
        allow_any_instance_of(StagingWorkflow).to receive(:save).and_return(false)
        post :create, params: { project: project.name }
      end

      it { expect(StagingWorkflow.count).to eq(0) }
      it { expect(response).to render_template(:new) }
      it { expect(flash[:error]).not_to be_nil }
    end
  end

  describe 'GET #show' do
    context 'non existent staging_workflow for project' do
      before do
        get :show, params: { id: 5 }
      end

      it { expect(assigns[:staging_workflow]).to be_nil }
      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).not_to be_nil }
    end

    context 'with an existent staging_workflow for project' do
      before do
        project.create_staging
        get :show, params: { id: project.staging }
      end

      it { expect(assigns[:staging_workflow]).to eq(project.staging) }
      it { expect(assigns[:project]).to eq(project) }
      it { expect(response).to render_template(:show) }
    end
  end

  describe 'GET #edit' do
    context 'non existent staging_workflow for project' do
      before do
        get :edit, params: { id: 5 }
      end

      it { expect(assigns[:staging_workflow]).to be_nil }
      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).not_to be_nil }
    end

    context 'with an existent staging_workflow for project' do
      before do
        project.create_staging
        get :edit, params: { id: project.staging }
      end

      it { expect(assigns[:staging_workflow]).to eq(project.staging) }
      it { expect(assigns[:project]).to eq(project) }
      it { expect(response).to render_template(:edit) }
    end
  end
end
