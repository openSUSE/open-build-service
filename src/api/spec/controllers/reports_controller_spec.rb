RSpec.describe ReportsController do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }
  let(:report) { create(:report, reporter: user) }

  before do
    Flipper.enable(:content_moderation)
    login user
  end

  describe 'GET index' do
    it 'returns ok' do
      get :index, format: :xml

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET show' do
    render_views # For response validation

    it 'returns ok' do
      get :show, format: :xml, params: { id: report.id }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST create' do
    render_views

    let(:other_user) { create(:confirmed_user) }

    context 'when category is a valid enum value' do
      let(:report_xml) do
        "<report reportable_type='User' reportable_id='#{other_user.id}' category='spam'>Watch your language, please</report>"
      end

      it 'returns ok' do
        post :create, format: :xml, body: report_xml

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when category is not a valid enum value' do
      let(:report_xml) do
        "<report reportable_type='User' reportable_id='#{other_user.id}' category='invalid_value'>Watch your language, please</report>"
      end

      it 'returns bad_request with an error message' do
        post :create, format: :xml, body: report_xml

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include('Invalid attribute category for element report')
      end
    end
  end

  describe 'PUT update' do
    render_views

    context 'when category is a valid enum value' do
      it 'returns ok' do
        put :update, format: :xml, params: { id: report.id }, body: "<report category='spam'>New text</report>"

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when category is not a valid enum value' do
      it 'returns bad_request with an error message' do
        put :update, format: :xml, params: { id: report.id }, body: "<report category='invalid_value'>New text</report>"

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include('Invalid attribute category for element report')
      end
    end
  end

  describe 'DELETE destroy' do
    it 'returns ok' do
      delete :destroy, format: :xml, params: { id: report.id }

      expect(response).to have_http_status(:ok)
    end
  end
end
