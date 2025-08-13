RSpec.describe Webui::Groups::BsRequestsController do
  describe 'GET #index' do
    let(:group) { create(:group) }
    let(:user) { create(:confirmed_user) }

    context 'when the user has the request_index feature on' do
      let(:source_project) { create(:project_with_package, :as_submission_source) }
      let(:source_package) { source_project.packages.first }
      let(:target_project) { create(:project_with_package, name: 'a_target_project') }
      let(:target_package) { target_project.packages.first }
      let!(:bs_request) do
        create(:bs_request_with_submit_action,
               source_package: source_package,
               target_package: target_package)
      end

      before do
        Flipper.enable(:request_index, user)
        create(:relationship_project_group, group: group, project: target_project)
        login user
        get :index, params: params
      end

      context 'and when looking for incoming requests' do
        let(:params) { { group_title: group.title, involvement: [:incoming] } }

        it { expect(response).to have_http_status(:success) }
        it { expect(subject).to render_template(:index) }
        it { expect(assigns[:bs_requests]).to contain_exactly(bs_request) }
      end

      context 'and when looking for requests where the group has to review' do
        let!(:a_review) { create(:review, by_group: group.title, bs_request: bs_request) }
        let(:params) { { group_title: group.title, involvement: [:review] } }

        it { expect(response).to have_http_status(:success) }
        it { expect(subject).to render_template(:index) }
        it { expect(assigns[:bs_requests]).to contain_exactly(bs_request) }
      end
    end

    context 'when the user has the request_index feature off' do
      include_context 'a set of bs requests'

      let!(:relationship_project_group) { create(:relationship_project_group, group: group, project: target_project) }
      let!(:relationship_project_group2) { create(:relationship_project_group, group: group, project: target_project2) }
      let(:base_params) { { group_title: group.title, format: :json, dataTableId: 'requests_in_table' } }
      let(:context_params) { {} }
      let(:params) { base_params.merge(context_params) }

      # this is to overwrite request3 because we set the relationship between group and target_project and target_project2
      # which would include request3 as well which we don't want. Therefore we overwrite it here with a different target_project3
      let!(:target_project3) { create(:project_with_package, name: 'c_target_project') }
      let!(:target_package3) { target_project3.packages.first }

      # for the reviews and all requests table
      let(:bs_request) { travel_to(1.day.ago) { create(:set_bugowner_request) } }
      let!(:review) { create(:review, by_group: group.title, bs_request: bs_request) }
      let(:another_group) { create(:group) }
      let(:another_bs_request) { create(:set_bugowner_request) }
      let!(:another_review) { create(:review, by_group: another_group.title, bs_request: another_bs_request) }
      let(:user) { User.find_by(login: bs_request.creator) }

      let!(:request3) do
        create(:bs_request_with_submit_action,
               creator: user2,
               priority: 'critical',
               source_package: source_package2,
               target_package: target_package3)
      end

      before do
        login user
        bs_request.state = :review
        bs_request.save
        another_bs_request.state = :review
        another_bs_request.save
        get :index, params: params
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(subject).to render_template(:index) }

      it_behaves_like 'a bs requests data table controller'

      context 'with the dataTableId param set to "reviews_in_table"' do
        let(:context_params) { { dataTableId: 'reviews_in_table' } }

        it 'returns those requests' do
          expect(assigns(:requests_data_table).rows.length).to eq(1)
          expect(assigns(:requests_data_table).rows.first.request).to eq(bs_request)
        end

        it 'assigns the total count of records' do
          expect(assigns(:requests_data_table).records_total).to eq(1)
          expect(assigns(:requests_data_table).count_requests).to eq(1)
        end
      end

      context 'with the dataTableId param set to "all_requests_table"' do
        let(:context_params) { { dataTableId: 'all_requests_table' } }

        it 'returns those requests' do
          expect(assigns(:requests_data_table).rows.length).to eq(12)
          expect(assigns(:requests_data_table).rows.first.request).to eq(request1)
          expect(assigns(:requests_data_table).rows.last.request).to eq(request2)
        end

        it 'assigns the total count of records' do
          expect(assigns(:requests_data_table).records_total).to eq(12)
          expect(assigns(:requests_data_table).count_requests).to eq(12)
        end
      end
    end
  end
end
