require 'rails_helper'

RSpec.describe Webui::StatusMessagesController do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  describe 'POST create' do
    it 'create a status message' do
      login(admin_user)

      post :create, params: { message: 'Some message', severity: 'Green' }
      expect(response).to redirect_to(root_path)
      message = StatusMessage.where(user: admin_user, message: 'Some message', severity: 'Green')
      expect(message).to exist
    end

    it 'requires message and severity parameters' do
      login(admin_user)

      expect do
        post :create, params: { message: 'Some message' }
      end.not_to change(StatusMessage, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Could not create status message: Severity can't be blank")

      expect do
        post :create, params: { severity: 'Green' }
      end.not_to change(StatusMessage, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Could not create status message: Message can't be blank")
    end

    context 'non-admin users' do
      before do
        login(user)

        post :create, params: { message: 'Some message', severity: 'Green' }
      end

      it 'does not create a status message' do
        expect(response).to redirect_to(root_path)
        message = StatusMessage.where(user: admin_user, message: 'Some message', severity: 'Green')
        expect(message).not_to exist
      end
    end

    context 'empty message' do
      before do
        login(admin_user)
        post :create, params: { severity: 'Green' }
      end

      it { expect(flash[:error]).to eq("Could not create status message: Message can't be blank") }
    end

    context 'empty severity' do
      before do
        login(admin_user)
        post :create, params: { message: 'Some message' }
      end

      it { expect(flash[:error]).to eq("Could not create status message: Severity can't be blank") }
    end

    context 'that fails at saving the message' do
      before do
        login(admin_user)
        allow_any_instance_of(StatusMessage).to receive(:save).and_return(false)
        post :create, params: { message: 'Some message', severity: 'Green' }
      end

      it { expect(flash[:error]).not_to be(nil) }
    end
  end

  describe 'DELETE destroy' do
    let(:message) { create(:status_message, user: admin_user) }

    it 'marks a message as deleted' do
      login(admin_user)

      delete :destroy, params: { id: message.id }
      expect(response).to redirect_to(root_path)
      expect(message.reload.deleted_at).to be_a_kind_of(ActiveSupport::TimeWithZone)
    end

    context 'non-admin users' do
      before do
        login(user)
        delete :destroy, params: { id: message.id }
      end

      it "can't delete messages" do
        expect(response).to redirect_to(root_path)
        expect(message.reload.deleted_at).to be(nil)
      end
    end
  end

  describe 'GET #create_status_message_dialog' do
    before do
      get :create_status_message_dialog, xhr: true
    end

    it { is_expected.to respond_with(:success) }
  end

  describe 'GET #destroy_status_message_dialog' do
    before do
      get :destroy_status_message_dialog, xhr: true
    end

    it { is_expected.to respond_with(:success) }
  end
end
