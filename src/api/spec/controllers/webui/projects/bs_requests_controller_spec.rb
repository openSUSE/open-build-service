require 'rails_helper'

RSpec.describe Webui::Projects::BsRequestsController do
  describe 'GET #index' do
    include_context 'a set of bs requests'

    let(:base_params) { { project: source_project, format: :json } }
    let(:context_params) { {} }
    let(:params) { base_params.merge(context_params) }

    before do
      get :index, params: params
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(subject).to render_template(:index) }

    it_behaves_like 'a bs requests data table controller'

    context 'with the state param set to "new"' do
      let(:context_params) { { state: 'new' } }

      it 'returns the requests with state = "new"' do
        expect(assigns(:requests_data_table).rows.length).to eq(11)
      end

      it 'assigns the total count of records' do
        expect(assigns(:requests_data_table).records_total).to eq(11)
        expect(assigns(:requests_data_table).count_requests).to eq(11)
      end
    end

    context 'with the state param set to "deleted"' do
      let(:context_params) { { state: 'deleted' } }

      it 'returns no requests' do
        expect(assigns(:requests_data_table).rows.length).to eq(0)
      end

      it 'assigns the total count of records' do
        expect(assigns(:requests_data_table).records_total).to eq(0)
        expect(assigns(:requests_data_table).count_requests).to eq(0)
      end
    end

    context 'with the type param set to "submit"' do
      let(:context_params) { { type: 'submit' } }

      it 'returns the requests with type = "submit"' do
        expect(assigns(:requests_data_table).rows.length).to eq(11)
      end

      it 'assigns the total count of records' do
        expect(assigns(:requests_data_table).records_total).to eq(11)
        expect(assigns(:requests_data_table).count_requests).to eq(11)
      end
    end

    context 'with the type param set to "delete"' do
      let(:context_params) { { type: 'delete' } }

      it 'returns no requests' do
        expect(assigns(:requests_data_table).rows.length).to eq(0)
      end

      it 'assigns the total count of records' do
        expect(assigns(:requests_data_table).records_total).to eq(0)
        expect(assigns(:requests_data_table).count_requests).to eq(0)
      end
    end
  end
end
