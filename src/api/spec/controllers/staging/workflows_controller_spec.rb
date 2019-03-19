require 'rails_helper'

RSpec.describe Staging::WorkflowsController, type: :controller, vcr: true do
  let(:other_user) { create(:confirmed_user, login: 'unpermitted_user') }
  let(:user) { create(:confirmed_user, login: 'permitted_user') }
  let(:project) { user.home_project }
  let(:group) { create(:group) }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }

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

      it { expect(response).to have_http_status(:not_found) }
      it { expect(project.staging).to be_nil }
    end
  end
end
