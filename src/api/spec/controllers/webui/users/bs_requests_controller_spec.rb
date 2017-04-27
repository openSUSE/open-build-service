require 'rails_helper'

RSpec.describe Webui::Users::BsRequestsController do
  let!(:user) { create(:confirmed_user, login: "tom") }
  let!(:another_user) { create(:confirmed_user, login: "moi") }

  let!(:source_project) { create(:project_with_package) }
  let!(:source_package) { source_project.packages.first }
  let!(:target_project) { create(:project_with_package) }
  let!(:target_package) { target_project.packages.first }

  let!(:request1) do
    create(:bs_request_with_submit_action,
           creator: user,
           priority: 'critical',
           source_project: source_project,
           source_package: source_package,
           target_project: target_project,
           target_package: target_package)
  end
  let!(:request2) do
    create(:bs_request_with_submit_action,
           created_at: 2.days.ago,
           creator: user,
           source_project: source_project,
           source_package: source_package,
           target_project: target_project,
           target_package: target_package)
  end
  let!(:request3) { create(:bs_request, creator: another_user, commenter: another_user) }

  describe 'GET #index' do
    def assigned_rows
      assigns(:requests_data_table).rows
    end

    def assigned_records_total
      assigns(:requests_data_table).records_total
    end

    def assigned_count_requests
      assigns(:requests_data_table).count_requests
    end

    let(:params) { { user: user, format: :json, length: 10, start: 0 } }

    before do
      get :index, params: params
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(subject).to render_template(:index) }

    context 'with no :order parameter' do
      it 'defaults to sort by :created_at :desc' do
        expect(assigned_rows.first.created_at).to eq(request1.created_at)
        expect(assigned_rows.second.created_at).to eq(request2.created_at)
      end

      it 'assigns the total count of records' do
        expect(assigned_records_total).to eq(2)
        expect(assigned_count_requests).to eq(2)
      end
    end

    context 'with :order parameter set to :asc direction' do
      let(:params) do
        { user: user, format: :json, length: 10, start: 0, order: { '0' => { dir: :asc } } }
      end

      it 'respects sort by :asc direction parameter' do
        expect(assigned_rows.first.created_at).to eq(request2.created_at)
        expect(assigned_rows.second.created_at).to eq(request1.created_at)
      end
    end

    context 'with :order parameter set to a column number' do
      let(:params) do
        { user: user, format: :json, length: 10, start: 0, order: { '0' => { column: 5 } } }
      end

      it 'respects sort by column priority parameter' do
        expect(assigned_rows.first.priority).to eq('moderate')
        expect(assigned_rows.second.priority).to eq('critical')
      end
    end

    context 'with a search value parameter set' do
      let(:params) do
        { user: user, format: :json, length: 10, start: 0, search: { value: 'critical' } }
      end

      it 'respects sort by column priority parameter' do
        expect(assigned_rows.length).to eq(1)
        expect(assigned_rows.first.priority).to eq('critical')
      end

      it 'assigns the total count of records' do
        expect(assigned_records_total).to eq(2)
        expect(assigned_count_requests).to eq(1)
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
        let(:params) do
          { user: user, format: :json, length: 10, start: 0 }
        end

        it 'assigns an array containing the first 10 requests' do
          expect(assigned_rows.length).to eq(10)
          expect(assigned_rows.first.created_at).to eq(request1.created_at)
        end

        it 'assigns the total count of records' do
          expect(assigned_records_total).to eq(11)
          expect(assigned_count_requests).to eq(11)
        end
      end

      context 'with :length parameter set to 10 and :start set to 10' do
        let(:params) do
          { user: user, format: :json, length: 10, start: 10 }
        end

        it 'assigns an array containing the last request' do
          expect(assigned_rows.length).to eq(1)
          expect(assigned_rows.first.created_at).to eq(request2.created_at)
        end

        it 'assigns the total count of records' do
          expect(assigned_records_total).to eq(11)
          expect(assigned_count_requests).to eq(11)
        end
      end
    end
  end
end
