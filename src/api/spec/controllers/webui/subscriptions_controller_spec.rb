# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webui::SubscriptionsController do
  describe 'GET #index' do
    let!(:admin) { create(:admin_user) }

    before do
      login admin
      get :index
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(response).to render_template(:index) }
    it { is_expected.to use_before_action(:require_admin) }
  end

  describe 'PUT #index' do
    let!(:admin) { create(:admin_user) }
    include_context 'a user and subscriptions with defaults'

    let(:params) { { subscriptions: subscription_params } }

    before do
      login admin
      put :update, params: params
    end

    it { expect(response).to redirect_to(action: :index) }
    it { is_expected.to use_before_action(:require_admin) }
    it_behaves_like 'a subscriptions form for default'
  end
end
