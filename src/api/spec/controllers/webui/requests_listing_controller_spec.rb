RSpec.describe Webui::RequestsListingController do
  let(:submitter) { create(:confirmed_user, :with_home, login: 'kugelblitz') }
  let(:receiver) { create(:confirmed_user, :with_home, login: 'titan') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package_with_file, name: 'goal', project_id: target_project.id) }
  let(:source_project) { submitter.home_project }
  let(:source_package) { create(:package, :as_submission_source, name: 'ball', project: source_project) }
  let(:reviewer) { create(:confirmed_user, login: 'klasnic') }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           description: 'Please take this',
           creator: submitter,
           target_package: target_package,
           source_package: source_package)
  end
  let(:request_with_review) do
    create(:bs_request_with_submit_action,
           review_by_user: reviewer,
           target_package: target_package,
           source_package: source_package)
  end

  it { is_expected.to use_before_action(:require_login) }

  describe 'GET #index' do
    before do
      bs_request
      request_with_review
      login receiver
    end

    context 'as user with requests' do
      before do
        get :index
      end

      it 'responds successfully' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns @bs_requests' do
        expect(assigns(:bs_requests)).to contain_exactly(bs_request, request_with_review)
      end
    end

    context 'as user with requests filtering by accepted state' do
      before do
        get :index, params: { state: ['review'] }
      end

      it 'assigns @bs_requests applying state filter' do
        expect(assigns(:bs_requests)).to contain_exactly(request_with_review)
      end
    end
  end
end
