require 'rails_helper'

RSpec.describe Webui::Users::BsRequestsController do
  let(:user) { create(:confirmed_user, login: "tom") }

  it { is_expected.to use_before_action(:check_display_user) }

  describe 'GET #index' do
    before do
      get :index, params: { user: user, format: :json, length: 10, start: 0 }
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(subject).to render_template(:index) }

    context 'with several requests belonging to different users' do
      let(:another_user) { create(:confirmed_user, login: "moi") }
      let!(:bs_request) { create(:bs_request, creator: user, commenter: user) }
      let!(:another_bs_request) { create(:bs_request, creator: another_user, commenter: another_user) }

      it 'only renders requests belonging to the user' do
        expect(assigns(:requests_data_table).rows.first.created_at).to eq(bs_request.created_at)
        expect(assigns(:requests_data_table).rows.length).to eq(1)
      end
    end
  end
end
