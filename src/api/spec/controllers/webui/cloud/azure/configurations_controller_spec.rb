require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::Cloud::Azure::ConfigurationsController, type: :controller, vcr: true do
  let!(:user) { create(:confirmed_user, login: 'tom') }

  before do
    login(user)
  end

  describe 'GET #show' do
    context 'without Azure configuration' do
      before do
        Feature.run_with_activated(:cloud_upload, :cloud_upload_azure) do
          get :show
        end
      end

      it 'creates an Azure configuration' do
        expect(assigns(:azure_configuration)).not_to be_nil
      end
    end

    context 'with Azure configuration' do
      let!(:azure_configuration) { create(:azure_configuration, user: user) }

      before do
        Feature.run_with_activated(:cloud_upload, :cloud_upload_azure) do
          get :show
        end
      end

      it { expect(assigns(:azure_configuration)).to eq(azure_configuration) }
    end
  end

  describe 'PUT #update' do
    let(:azure_configuration) { create(:azure_configuration, user: user) }

    context 'with valid parameters' do
      before do
        azure_configuration

        Feature.run_with_activated(:cloud_upload, :cloud_upload_azure) do
          put :update, params: { cloud_azure_configuration: { application_id: 'random_string', application_key: 'random_string_2' } }
        end
        azure_configuration.reload
      end

      it { expect(flash[:success]).not_to be_nil }
    end

    context 'with invalid parameters' do
      before do
        azure_configuration

        Feature.run_with_activated(:cloud_upload, :cloud_upload_azure) do
          put :update, params: { cloud_azure_configuration: { application_id: '' } }
        end
        azure_configuration.reload
      end

      it { expect(flash[:error]).not_to be_nil }
    end
  end

  describe 'DELETE #destroy' do
    let(:azure_configuration) { create(:azure_configuration, user: user) }

    before do
      azure_configuration

      Feature.run_with_activated(:cloud_upload, :cloud_upload_azure) do
        delete :destroy
      end
    end

    it { expect(flash[:success]).not_to be_nil }
    it { expect(response).to redirect_to(cloud_azure_configuration_path) }
  end
end
