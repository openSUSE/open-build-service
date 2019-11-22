require 'rails_helper'

RSpec.describe Staging::WorkflowsController do
  let(:other_user) { create(:confirmed_user, :with_home, login: 'unpermitted_user') }
  let(:user) { create(:confirmed_user, :with_home, login: 'permitted_user') }
  let(:project) { user.home_project }
  let(:group) { create(:group) }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project, managers_group: group) }
  let(:other_group) { create(:group) }
  let(:other_project) { other_user.home_project }

  describe 'POST #create' do
    context 'with valid staging_project' do
      before do
        login user
        post :create, params: { staging_workflow_project: project, format: :xml },
                      body: "<workflow managers='#{group}'/>"
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(project.staging).not_to be_nil }
    end

    context 'invalid user' do
      before do
        login other_user
        post :create, params: { staging_workflow_project: project, format: :xml },
                      body: "<workflow managers='#{group}'/>"
      end

      it { expect(response).to have_http_status(:forbidden) }
      it { expect(project.staging).to be_nil }
    end

    context 'non-existent project' do
      before do
        login user
        post :create, params: { staging_workflow_project: 'imaginary_project', format: :xml },
                      body: "<workflow managers='#{group}'/>"
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'without group' do
      before do
        login user
        post :create, params: { staging_workflow_project: project, format: :xml }
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(project.staging).to be_nil }
    end
  end

  describe 'DELETE #destroy' do
    context 'with valid staging_project with staging_workflow' do
      before do
        login user
        staging_workflow
        delete :destroy, params: { staging_workflow_project: project, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(project.reload.staging).to be_nil }
    end

    context 'delete staging projects of a staging workflow by passing the "with_staging_projects" param' do
      let!(:staging_projects) { staging_workflow.staging_projects.map(&:name) }

      before do
        login user
        delete :destroy, params: { staging_workflow_project: project, with_staging_projects: 1, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(project.reload.staging).to be_nil }
      it { expect(Project.exists?(name: staging_projects)).to be false }
    end

    context 'with invalid user' do
      before do
        login user
        staging_workflow
        login other_user
        delete :destroy, params: { staging_workflow_project: project, format: :xml }
      end

      it { expect(response).to have_http_status(:forbidden) }
      it { expect(project.reload.staging).not_to(be_nil) }
    end

    context 'with non-existent project' do
      before do
        login user
        delete :destroy, params: { staging_workflow_project: 'imaginary_project', format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'with project without staging_workflow' do
      before do
        login user
        delete :destroy, params: { staging_workflow_project: project, format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'PUT #update' do
    let(:source_project) { create(:project, name: 'source_project') }
    let(:target_package) { create(:package, name: 'target_package', project: project) }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }
    let(:other_user) { create(:confirmed_user, :with_home, login: 'other_user') }
    let(:bs_request) do
      create(:bs_request_with_submit_action,
             creator: other_user,
             target_package: target_package,
             source_package: source_package)
    end

    context 'with a valid managers group' do
      before do
        login user
        staging_workflow
        bs_request
        put :update, params: { staging_workflow_project: staging_workflow.project, format: :xml },
                     body: "<workflow managers='#{other_group}'/>"
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(staging_workflow.reload.managers_group.title).to eq(other_group.title) }
      it { expect(bs_request.reviews.find_by(by_group: group.title).state).to eq(:accepted) }
      it { expect(bs_request.reviews.find_by(by_group: other_group.title).state).to eq(:new) }
    end

    context 'with a project that is not a staging workflow' do
      before do
        login user
        put :update, params: { staging_workflow_project: other_project, format: :xml },
                     body: "<workflow managers='#{group}'/>"
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'invalid user' do
      before do
        staging_workflow
        login other_user
        put :update, params: { staging_workflow_project: staging_workflow.project, format: :xml },
                     body: "<workflow managers='#{other_group}'/>"
      end

      it { expect(response).to have_http_status(:forbidden) }
      it { expect(staging_workflow.reload.managers_group.title).to eq(group.title) }
    end

    context 'non-existent group' do
      before do
        login user
        put :update, params: { staging_workflow_project: staging_workflow.project, format: :xml },
                     body: "<workflow managers='imaginary_group'/>"
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end
end
