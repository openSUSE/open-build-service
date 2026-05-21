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
    let(:other_user) { create(:confirmed_user) }
    let(:report_xml) do
      "<report reportable_type='User' reportable_id='#{other_user.id}'>Watch your language, please</report>"
    end

    it 'returns ok' do
      post :create, format: :xml, body: report_xml

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PUT update' do
    it 'returns ok' do
      put :update, format: :xml, params: { id: report.id }, body: '<report>New text</report>'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE destroy' do
    it 'returns ok' do
      delete :destroy, format: :xml, params: { id: report.id }

      expect(response).to have_http_status(:ok)
    end
  end
end
