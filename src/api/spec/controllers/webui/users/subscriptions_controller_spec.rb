# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Webui::Users::SubscriptionsController do
  describe 'GET #index' do
    let!(:user) { create(:confirmed_user) }

    before do
      login user
      get :index
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(response).to render_template(:index) }
    it { is_expected.to use_before_action(:require_login) }
  end

  describe 'PUT #index' do
    include_context 'a user and subscriptions with defaults'

    let(:params) { { subscriptions: subscription_params } }

    before do
      login user
      put :update, params: params
    end

    it { expect(response).to redirect_to(action: :index) }
    it { is_expected.to use_before_action(:require_login) }
    it_behaves_like 'a subscriptions form for subscriber'
  end
end
