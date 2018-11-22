require 'rails_helper'

RSpec.describe Staging::StagedRequestsController, type: :controller, vcr: true do
  render_views

  let(:other_user) { create(:confirmed_user, login: 'unpermitted_user') }
  let(:user) { create(:confirmed_user, login: 'permitted_user') }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
  let(:group) { staging_workflow.managers_group }
  let(:staging_project) { staging_workflow.staging_projects.first }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:review) { create(:review, by_group: group.title) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           state: :review,
           creator: other_user,
           target_project: project.name,
           target_package: target_package.name,
           source_project: source_project.name,
           source_package: source_package.name,
           description: 'BsRequest 1',
           reviews: [review])
  end

  describe 'GET #index' do
    before do
      bs_request.staging_project = staging_project
      bs_request.save
      get :index, params: { staging_main_project_name: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml }
    end

    it { expect(response).to have_http_status(:success) }
    it 'returns the staged_requests xml' do
      assert_select 'staged_requests' do
        assert_select 'request', 1
      end
    end
  end

  describe 'POST #create' do
    context 'invalid user' do
      before do
        staging_workflow

        login other_user
        post :create, params: { staging_main_project_name: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                      body: "<requests><number>#{bs_request.number}</number></requests>"
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'non-existent staging project' do
      before do
        login user
        post :create, params: { staging_main_project_name: staging_workflow.project.name, staging_project_name: 'does-not-exist', format: :xml },
                      body: "<requests><number>#{bs_request.number}</number></requests>"
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'with valid and invalid request number' do
      before do
        login user
        post :create, params: { staging_main_project_name: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                      body: "<requests><number>-1</number><number>#{bs_request.number}</number></requests>"
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(staging_project.packages.pluck(:name)).to match_array([target_package.name]) }
    end

    context 'with valid staging_project' do
      before do
        login user
        post :create, params: { staging_main_project_name: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                      body: "<requests><number>#{bs_request.number}</number></requests>"
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(staging_project.packages.pluck(:name)).to match_array([target_package.name]) }
    end
  end

  describe 'DELETE #destroy' do
    let!(:package) { create(:package, name: target_package, project: staging_project) }

    before do
      bs_request.staging_project = staging_project
      bs_request.save
    end

    context 'invalid user' do
      before do
        login other_user
        delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                         body: "<requests><number>#{bs_request.number}</number></requests>"
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'with invalid staging project' do
      before do
        login user
        delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, staging_project_name: 'does-not-exist', format: :xml },
                         body: "<requests><number>#{bs_request.number}</number></requests>"
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'valid staging project and valid user' do
      context 'with valid request number' do
        before do
          login user
          delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                           body: "<requests><number>#{bs_request.number}</number></requests>"
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(staging_project.packages).to be_empty }
        it { expect(staging_project.staged_requests).to be_empty }
      end

      context 'with valid and invalid request number' do
        before do
          login user
          delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                           body: "<requests><number>-1</number><number>#{bs_request.number}</number></requests>"
        end

        it { expect(response).to have_http_status(:bad_request) }
        it { expect(staging_project.packages).to be_empty }
        it { expect(staging_project.staged_requests).to be_empty }
      end
    end
  end
end
