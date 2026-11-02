RSpec.describe Webui::ReportsController do
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }

  before do
    Flipper.enable(:content_moderation)
    login user
  end

  describe 'GET show' do
    render_views

    let(:user) { create(:moderator) }
    let(:report) { create(:report) }

    context 'when the reportable was deleted and the report has no decision' do
      before do
        report.reportable.destroy!
        get :show, params: { id: report.id }
      end

      it 'renders the report page' do
        expect(response).to have_http_status(:success)
        expect(response.body).to include('does not exist anymore.')
      end

      it 'includes the report in the decision form' do
        expect(response.body).to have_css("input[type='hidden'][name='decision[report_ids][]'][value='#{report.id}']", visible: :hidden)
      end
    end
  end

  describe 'POST create' do
    context 'when category is a valid enum value' do
      it 'sets a success flash message' do
        post :create, format: :js, params: { report: { reportable_type: 'User',
                                                       reportable_id: other_user.id,
                                                       category: 'spam',
                                                       reason: 'Watch your language' } }

        expect(flash[:success]).to be_present
      end
    end

    context 'when category is not a valid enum value' do
      it 'sets an error flash message' do
        post :create, format: :js, params: { report: { reportable_type: 'User',
                                                       reportable_id: other_user.id,
                                                       category: 'invalid_value',
                                                       reason: 'Watch your language' } }

        expect(flash[:error]).to include("'invalid_value' is not a valid category")
      end
    end
  end
end
