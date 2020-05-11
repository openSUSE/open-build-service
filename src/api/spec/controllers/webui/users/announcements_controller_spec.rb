require 'rails_helper'

RSpec.describe Webui::Users::AnnouncementsController do
  describe 'POST #create' do
    let(:user) { create(:confirmed_user) }
    let(:announcement) { create(:announcement) }

    context 'called with an existing announcement' do
      before do
        login user
        post :create, params: { id: announcement.id }, xhr: true
      end

      it { expect(response).to render_template(:create) }
      it { expect(response).to have_http_status(:success) }
      it { expect(user.announcements).to include(announcement) }
    end

    context 'called with a non-existing announcement' do
      before do
        login user
        post :create, params: { id: 42_000 }, xhr: true
      end

      it { expect(flash[:error]).to eq("Couldn't find Announcement") }
    end
  end
end
