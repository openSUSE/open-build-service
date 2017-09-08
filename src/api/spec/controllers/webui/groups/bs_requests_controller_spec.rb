require 'rails_helper'

RSpec.describe Webui::Groups::BsRequestsController do
  describe 'GET #index' do
    include_context 'a set of bs requests'

    let(:group) { create(:group) }
    let!(:relationship_project_group) { create(:relationship_project_group, group: group, project: target_project) }
    let!(:relationship_project_group2) { create(:relationship_project_group, group: group, project: target_project2) }
    let(:base_params) { { title: group.title, format: :json, dataTableId: 'requests_in_table' } }
    let(:context_params) { { } }
    let(:params) { base_params.merge(context_params) }

    # this is for overwritting request3 because we set the relationship between group and target_project and target_project2
    # which would include request3 as well which we don't want. Therefore we overwrite it here with a different target_project3
    let!(:target_project3) { create(:project_with_package, name: 'c_target_project') }
    let!(:target_package3) { target_project3.packages.first }
    let!(:request3) do
      create(:bs_request_with_submit_action,
             creator: user2,
             priority: 'critical',
             source_project: source_project2,
             source_package: source_package2,
             target_project: target_project3,
             target_package: target_package3)
    end

    before do
      get :index, params: params
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(subject).to render_template(:index) }

    it_behaves_like 'a bs requests data table controller'

    context 'with the dataTableId param set to "reviews_in_table"' do
      let(:context_params) { { dataTableId: 'reviews_in_table' } }
      let(:bs_request) { create(:bs_request) }
      let!(:review) { create(:review, by_group: group.title, bs_request: bs_request) }
      let(:another_group) { create(:group) }
      let(:another_bs_request) { create(:bs_request) }
      let!(:another_review) { create(:review, by_group: another_group.title, bs_request: another_bs_request) }

      before do
        bs_request.state = :review
        bs_request.save
        another_bs_request.state = :review
        another_bs_request.save
      end

      it 'returns those requests' do
        expect(assigns(:requests_data_table).rows.length).to eq(1)
        expect(assigns(:requests_data_table).rows.first.request).to eq(bs_request)
      end

      it 'assigns the total count of records' do
        expect(assigns(:requests_data_table).records_total).to eq(1)
        expect(assigns(:requests_data_table).count_requests).to eq(1)
      end
    end
  end
end
