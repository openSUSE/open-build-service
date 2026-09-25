RSpec.describe Webui::ReportsController do
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }

  before do
    Flipper.enable(:content_moderation)
    login user
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
