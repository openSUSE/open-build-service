RSpec.describe Webui::Users::BsRequestsController do
  describe 'GET #index' do
    context 'when the user has the request_index feature flag disabled' do
      include_context 'a set of bs requests'

      let(:context_params) { {} }
      let(:params) { { user_login: user, format: :json }.merge(context_params) }

      before do
        login user
        get :index, params: params
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(subject).to render_template(:index) }

      it_behaves_like 'a bs requests data table controller'

      context 'with the dataTableId param set to "all_requests_table"' do
        let(:context_params) { { dataTableId: 'all_requests_table' } }

        it 'returns those requests' do
          expect(assigns(:requests_data_table).rows.length).to eq(11)
        end

        it 'assigns the total count of records' do
          expect(assigns(:requests_data_table).records_total).to eq(11)
          expect(assigns(:requests_data_table).count_requests).to eq(11)
        end
      end

      context 'with the dataTableId param set to "requests_in_table"' do
        let(:context_params) { { dataTableId: 'requests_in_table' } }

        it 'returns no requests' do
          expect(assigns(:requests_data_table).rows.length).to eq(0)
        end

        it 'assigns the total count of records' do
          expect(assigns(:requests_data_table).records_total).to eq(0)
          expect(assigns(:requests_data_table).count_requests).to eq(0)
        end
      end
    end

    context 'when the user has the request_index feature flag enabled' do
      let!(:user) { create(:confirmed_user, login: 'king') }
      let(:target_project) { create(:project_with_package, maintainer: user) }
      let(:target_package) { target_project.packages.first }
      let!(:incoming_request) do
        create(:bs_request_with_submit_action,
               priority: 'critical',
               source_package: create(:project),
               target_package: target_package)
      end
      let!(:outgoing_request) do
        create(:bs_request_with_submit_action,
               creator: user,
               priority: 'critical',
               source_package: target_package,
               target_package: create(:project))
      end
      let(:params) { { format: :json }.merge(context_params) }

      before do
        login user
        Flipper.enable(:request_index, user)
        get :index, params: params, format: :html
      end

      context 'and the direction parameters is "incoming"' do
        let(:context_params) { { direction: 'incoming' } }

        it { expect(response).to have_http_status(:success) }
        it { expect(subject).to render_template(:index) }
        it { expect(assigns[:bs_requests]).to include(incoming_request) }
        it { expect(assigns[:bs_requests]).not_to include(outgoing_request) }
      end

      context 'and the direction parameters is "outgoing"' do
        let(:context_params) { { direction: 'outgoing' } }

        it { expect(response).to have_http_status(:success) }
        it { expect(subject).to render_template(:index) }
        it { expect(assigns[:bs_requests]).not_to include(incoming_request) }
        it { expect(assigns[:bs_requests]).to include(outgoing_request) }
      end

      context 'and the direction parameters is "all"' do
        let(:context_params) { { direction: 'all' } }

        it { expect(response).to have_http_status(:success) }
        it { expect(subject).to render_template(:index) }
        it { expect(assigns[:bs_requests]).to include(incoming_request) }
        it { expect(assigns[:bs_requests]).to include(outgoing_request) }
      end
    end
  end
end
