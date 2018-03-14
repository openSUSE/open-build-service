require 'rails_helper'

RSpec.describe Webui::Users::RssTokensController do
  describe 'POST #create' do
    let(:user) { create(:confirmed_user) }

    before do
      login(user)
    end

    context 'with a user with an existent token' do
      before do
        @last_token = user.create_rss_token.string
        post :create
      end

      it { expect(flash[:success]).to eq('Successfully re-generated your RSS feed url') }
      it { is_expected.to redirect_to(user_notifications_path) }
      it { expect(user.reload.rss_token.string).to_not eq(@last_token) }
    end

    context 'with a user without a token' do
      before do
        @last_token = user.rss_token
        post :create
      end

      it { expect(flash[:success]).to eq('Successfully generated your RSS feed url') }
      it { is_expected.to redirect_to(user_notifications_path) }
      it { expect(user.reload.rss_token).to_not be_nil }
      it { expect(@last_token).to be_nil }
    end
  end
end
