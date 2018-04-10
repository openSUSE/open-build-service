# frozen_string_literal: true

RSpec.shared_examples 'a bs requests data table controller' do
  context 'with no :order parameter' do
    it 'defaults to sort by :created_at :desc' do
      expect(assigns(:requests_data_table).rows.first.created_at).to eq(request1.created_at)
      expect(assigns(:requests_data_table).rows.last.created_at).to eq(request2.created_at)
    end

    it 'assigns the total count of records' do
      expect(assigns(:requests_data_table).records_total).to eq(11)
      expect(assigns(:requests_data_table).count_requests).to eq(11)
    end
  end

  context 'with :order parameter set to :asc direction' do
    let(:context_params) { { order: { '0' => { dir: :asc } } } }

    it 'respects sort by :asc direction parameter' do
      expect(assigns(:requests_data_table).rows.first.created_at).to eq(request2.created_at)
      expect(assigns(:requests_data_table).rows.last.created_at).to eq(request1.created_at)
    end
  end

  context 'with :order parameter set to a column number' do
    let(:context_params) { { order: { '0' => { column: 5 } } } }

    it 'respects sort by column priority parameter' do
      expect(assigns(:requests_data_table).rows.first.priority).to eq('moderate')
      expect(assigns(:requests_data_table).rows.last.priority).to eq('critical')
    end
  end

  context 'with :order parameter set to a column number of a composite column' do
    let(:context_params) { { order: { '0' => { column: 2 } } } }

    it 'respects sort by column target_project and target_package parameter' do
      expect(assigns(:requests_data_table).rows.first.request).to eq(request4)
    end
  end

  context 'with a search value parameter set' do
    let(:context_params) { { search: { value: 'critical' } } }

    it 'respects sort by column priority parameter' do
      expect(assigns(:requests_data_table).rows.length).to eq(1)
      expect(assigns(:requests_data_table).rows.first.priority).to eq('critical')
    end

    it 'assigns the total count of records' do
      expect(assigns(:requests_data_table).records_total).to eq(11)
      expect(assigns(:requests_data_table).count_requests).to eq(1)
    end
  end

  context 'with :length parameter set to 10 and :start set to 0' do
    let(:context_params) { { length: 10, start: 0 } }

    it 'assigns an array containing the first 10 requests' do
      expect(assigns(:requests_data_table).rows.length).to eq(10)
      expect(assigns(:requests_data_table).rows.first.created_at).to eq(request1.created_at)
    end

    it 'assigns the total count of records' do
      expect(assigns(:requests_data_table).records_total).to eq(11)
      expect(assigns(:requests_data_table).count_requests).to eq(11)
    end
  end

  context 'with :length parameter set to 10 and :start set to 10' do
    let(:context_params) { { length: 10, start: 10 } }

    it 'assigns an array containing the last request' do
      expect(assigns(:requests_data_table).rows.length).to eq(1)
      expect(assigns(:requests_data_table).rows.first.created_at).to eq(request2.created_at)
    end

    it 'assigns the total count of records' do
      expect(assigns(:requests_data_table).records_total).to eq(11)
      expect(assigns(:requests_data_table).count_requests).to eq(11)
    end
  end
end
