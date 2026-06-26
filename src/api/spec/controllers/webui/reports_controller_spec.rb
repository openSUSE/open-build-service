RSpec.describe Webui::ReportsController do
  let(:user) { create(:confirmed_user) }
  let(:report) { create(:report, reporter: user) }

  before do
    Flipper.enable(:content_moderation)
    login user
  end

  describe 'GET show' do
    render_views

    it 'renders the reports page when canned responses are enabled' do
      Flipper.enable(:canned_responses)
      create(:canned_response, user: user)

      get :show, params: { id: report.id }

      expect(response).to have_http_status(:ok)
    end
  end
end
