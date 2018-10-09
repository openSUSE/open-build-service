require 'rails_helper'

RSpec.describe StagingProjectsController, type: :controller do
  render_views

  describe 'GET #requests_to_review' do
    let(:user) { create(:confirmed_user) }
    let(:factory) { create(:project, name: 'openSUSE:Factory') }
    let(:factory_staging) { create(:project, name: 'openSUSE:Factory:Staging') }
    let(:staging_project) { create(:project, name: 'openSUSE:Factory:Staging:A', description: 'Factory staging project A') }
    let(:source_package) { create(:package) }
    let(:target_package) { create(:package, name: 'target_package', project: factory) }
    let!(:create_review_requests_in_state_new) do
      create(:review_bs_request_by_project,
             number: 31337,
             reviewer: staging_project.name,
             request_state: 'review',
             target_project: factory.name,
             target_package: target_package.name,
             source_project: source_package.project.name,
             source_package: source_package.name)
    end

    before do
      login user
      get :requests_to_review, params: { project: staging_project.name, format: :xml }
    end

    it { expect(response).to have_http_status(:success) }
    it 'returns the reviews xml' do
      assert_select 'reviews' do
        assert_select 'request', 1
      end
    end
  end
end
