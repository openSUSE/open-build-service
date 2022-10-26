require 'rails_helper'

RSpec.describe Webui::Cloud::Azure::ConfigurationsController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }

  describe 'GET #show' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'without Azure configuration' do
      before do
        login(user)
        get :show
      end

      it 'creates an Azure configuration' do
        expect(assigns(:azure_configuration)).not_to be_nil
      end
    end

    context 'with Azure configuration' do
      let!(:azure_configuration) { create(:azure_configuration, user: user) }

      before do
        login(user)
        get :show
      end

      it { expect(assigns(:azure_configuration)).to eq(azure_configuration) }
    end
  end

  describe 'PUT #update' do
    let!(:azure_configuration) { create(:azure_configuration, user: user) }

    it { is_expected.to use_after_action(:verify_authorized) }

    context 'with valid parameters' do
      before do
        login(user)
        put :update, params: { cloud_azure_configuration: { application_id: 'random_string', application_key: 'random_string_2' } }
        azure_configuration.reload
      end

      it { expect(flash[:success]).not_to be_nil }
    end

    context 'with invalid parameters' do
      before do
        login(user)
        put :update, params: { cloud_azure_configuration: { application_id: '' } }
        azure_configuration.reload
      end

      it { expect(flash[:error]).not_to be_nil }
    end
  end

  describe 'DELETE #destroy' do
    let(:azure_configuration) { create(:azure_configuration, user: user) }

    it { is_expected.to use_after_action(:verify_authorized) }

    context 'for logged in user' do
      before do
        login(user)
        delete :destroy
      end

      it { expect(flash[:success]).not_to be_nil }
      it { expect(response).to redirect_to(cloud_azure_configuration_path) }
    end
  end
end
