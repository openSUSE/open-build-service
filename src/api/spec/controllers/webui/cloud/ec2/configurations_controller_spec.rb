require 'rails_helper'

RSpec.describe Webui::Cloud::Ec2::ConfigurationsController, type: :controller do
  let(:user) { create(:confirmed_user, login: 'tom') }
  before do
    login(user)
  end

  describe 'GET #show' do
    context 'without EC2 configuration' do
      before do
        Feature.run_with_activated(:cloud_upload) do
          get :show
        end
      end

      it 'creates an EC2 configuration' do
        expect(user.ec2_configuration).not_to be_nil
      end
    end

    context 'with EC2 configuration' do
      let!(:ec2_configuration) { create(:ec2_configuration, user: user) }

      before do
        Feature.run_with_activated(:cloud_upload) do
          get :show
        end
      end

      it { expect(user.ec2_configuration).to eq(ec2_configuration) }
    end
  end

  describe 'GET #update' do
    let!(:ec2_configuration) { create(:ec2_configuration, user: user) }

    context 'with valid parameters' do
      before do
        Feature.run_with_activated(:cloud_upload) do
          put :update, params: { ec2_configuration: { arn: 'arn:123:456' } }
        end
        ec2_configuration.reload
      end

      it { expect(ec2_configuration.arn).to eq('arn:123:456') }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'with invalid parameters' do
      before do
        Feature.run_with_activated(:cloud_upload) do
          put :update, params: { ec2_configuration: { arn: '123' } }
        end
      end

      it { expect(ec2_configuration.arn).not_to eq('123') }
      it { expect(flash[:error]).not_to be_nil }
    end
  end
end
