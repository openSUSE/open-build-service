require 'rails_helper'

RSpec.describe Webui::Users::SubscriptionsController do
  describe 'GET #index' do
    it_behaves_like 'require logged in user' do
      let(:method) { :get }
      let(:action) { :index }
    end

    context 'for logged in user' do
      let!(:user) { create(:confirmed_user) }

      before do
        login user
        get :index
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response).to render_template(:index) }
    end
  end

  describe 'PUT #update' do
    include_context 'a user and subscriptions with defaults'

    let(:params) { { subscriptions: subscription_params } }

    it_behaves_like 'require logged in user' do
      let(:method) { :put }
      let(:action) { :update }
      let(:opts) { { params: params } }
    end

    context 'for logged in user' do
      before do
        login user
        put :update, params: params
      end

      it { expect(response).to redirect_to(action: :index) }

      it_behaves_like 'a subscriptions form for subscriber'
    end
  end
end
