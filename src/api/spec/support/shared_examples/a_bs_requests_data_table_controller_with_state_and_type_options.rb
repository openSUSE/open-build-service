# frozen_string_literal: true
RSpec.shared_examples 'a bs requests data table controller with state and type options' do
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
