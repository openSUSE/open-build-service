require 'rails_helper'

RSpec.describe BsRequest::DataTable do
  let!(:user) { create(:confirmed_user, login: 'moi') }
  let(:source_project) { create(:project_with_package) }
  let(:source_package) { source_project.packages.first }
  let(:target_project) { create(:project_with_package) }
  let(:target_package) { target_project.packages.first }
  let!(:request_one) do
    create(:bs_request_with_submit_action,
           creator: user,
           priority: 'critical',
           source_project: source_project,
           source_package: source_package,
           target_project: target_project,
           target_package: target_package)
  end
  let!(:request_two) do
    create(:bs_request_with_submit_action,
           created_at: 2.days.ago,
           creator: user,
           source_project: source_project,
           source_package: source_package,
           target_project: target_project,
           target_package: target_package)
  end

  describe '#rows' do
    context 'with no :order parameter' do
      let(:rows) do
        BsRequest::DataTable.new({ length: 10, start: 0 }, user).rows
      end

      it 'defaults to sort by :created_at :desc' do
        expect(rows.first.created_at).to eq(request_one.created_at)
        expect(rows.second.created_at).to eq(request_two.created_at)
      end
    end

    context 'with :order parameter set to :asc direction' do
      let(:rows) do
        BsRequest::DataTable.new({ length: 10, start: 0, order: { '0' => { dir: :asc } } }, user).rows
      end

      it 'respects sort by :asc direction parameter' do
        expect(rows.first.created_at).to eq(request_two.created_at)
        expect(rows.second.created_at).to eq(request_one.created_at)
      end
    end

    context 'with :order parameter set to a column number' do
      let(:rows) do
        BsRequest::DataTable.new({ length: 10, start: 0, order: { '0' => { column: 5 } } }, user).rows
      end

      it 'respects sort by column priority parameter' do
        expect(rows.first.priority).to eq('moderate')
        expect(rows.second.priority).to eq('critical')
      end
    end

    context 'with a search value parameter set' do
      let(:rows) do
        BsRequest::DataTable.new({ length: 10, start: 0, search: { value: 'critical' } }, user).rows
      end

      it 'respects sort by column priority parameter' do
        expect(rows.length).to eq(1)
        expect(rows.first.priority).to eq('critical')
      end
    end

    context 'with many requests' do
      let!(:bs_requests) do
        create_list(:bs_request_with_submit_action,
                    9,
                    created_at: 1.day.ago,
                    creator: user,
                    source_project: source_project,
                    source_package: source_package,
                    target_project: target_project,
                    target_package: target_package)
      end

      context 'with :length parameter set to 10 and :start set to 0' do
        let(:rows) { BsRequest::DataTable.new({ length: 10, start: 0 }, user).rows }

        it 'returns an array containing the first 10 requests' do
          expect(rows.length).to eq(10)
          expect(rows.first.created_at).to eq(request_one.created_at)
        end
      end

      context 'with :length parameter set to 10 and :start set to 10' do
        let(:rows) { BsRequest::DataTable.new({ length: 10, start: 10 }, user).rows }

        it 'returns an array containing the last request' do
          expect(rows.length).to eq(1)
          expect(rows.first.created_at).to eq(request_two.created_at)
        end
      end
    end
  end

  describe '#draw' do
    let(:request_data_table) { BsRequest::DataTable.new({ draw: 3 }, user) }

    subject { request_data_table.draw }

    it { is_expected.to eq(4) }
  end

  describe '#records_total' do
    let(:request_data_table) { BsRequest::DataTable.new({ search: { value: 'critical' } }, user) }

    context 'with many requests' do
      let!(:bs_requests) do
        create_list(:bs_request_with_submit_action,
                    9,
                    created_at: 1.day.ago,
                    creator: user,
                    source_project: source_project,
                    source_package: source_package,
                    target_project: target_project,
                    target_package: target_package)
      end

      subject { request_data_table.records_total }

      it { is_expected.to eq(11) }
    end
  end

  describe '#count_requests' do
    let(:request_data_table) { BsRequest::DataTable.new({ search: { value: 'critical' } }, user) }

    subject { request_data_table.count_requests }

    it { is_expected.to eq(1) }
  end
end
