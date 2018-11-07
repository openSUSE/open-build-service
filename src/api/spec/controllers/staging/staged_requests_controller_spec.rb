require 'rails_helper'

RSpec.describe Staging::StagedRequestsController, type: :controller do
  render_views
  describe 'GET #index' do
    let(:user) { create(:confirmed_user, login: 'tom') }
    let(:project) { create(:project_with_package, name: 'MyProject') }
    let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
    let(:staging_project) { staging_workflow.staging_projects.first }
    let(:source_project) { create(:project, name: 'source_project') }
    let(:target_package) { create(:package, name: 'target_package', project: project) }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }
    let(:bs_request) do
      create(:bs_request_with_submit_action,
             target_project: project.name,
             target_package: target_package.name,
             source_project: source_project.name,
             source_package: source_package.name,
             description: 'BsRequest 1')
    end

    before do
      bs_request.staging_project = staging_project
      bs_request.save
      login user
      get :index, params: { project: staging_project.name, format: :xml }
    end

    it { expect(response).to have_http_status(:success) }
    it 'returns the staged_requests xml' do
      assert_select 'staged_requests' do
        assert_select 'request', 1
      end
    end
  end
end
