require 'rails_helper'

RSpec.describe Staging::BacklogController do
  render_views

  let(:other_user) { create(:confirmed_user, :with_home, login: 'unpermitted_user') }
  let(:user) { create(:confirmed_user, :with_home, login: 'permitted_user') }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
  let(:group) { staging_workflow.managers_group }
  let(:staging_project) { staging_workflow.staging_projects.first }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let!(:bs_request) do
    create(:bs_request_with_submit_action,
           state: :review,
           creator: other_user,
           target_package: target_package,
           source_package: source_package,
           description: 'BsRequest 1',
           review_by_group: group)
  end

  describe 'GET #index' do
    context 'when the project has an Staging Workflow' do
      before do
        get :index, params: { staging_workflow_project: staging_workflow.project.name, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }

      it 'returns the backlog xml' do
        expect(response.body).to have_selector('backlog > request', count: 1)
      end
    end

    context 'when the project does not exist' do
      before do
        get :index, params: { staging_workflow_project: 'non-existent', format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'when the project has no Staging Workflow' do
      let(:other_project) { other_user.home_project }

      before do
        get :index, params: { staging_workflow_project: other_project, format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }

      it 'responds_with_an_error' do
        expect(response.body).to have_selector('status > summary', text: "Project #{other_project} doesn't have an asociated Staging Workflow")
      end
    end
  end
end
