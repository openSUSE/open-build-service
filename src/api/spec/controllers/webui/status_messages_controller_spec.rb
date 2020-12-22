require 'rails_helper'

RSpec.describe Webui::StatusMessagesController do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  describe 'GET new' do
    it_behaves_like 'require logged in user' do
      let(:method) { :get }
      let(:action) { :new }
    end
  end

  describe 'POST create' do
    it_behaves_like 'require logged in user' do
      let(:method) { :post }
      let(:action) { :create }
      let(:opts) do
        { params: { status_message: { message: 'Some message' } } }
      end
    end

    it 'create a status message' do
      login(admin_user)

      post :create, params: { status_message: { message: 'Some message', severity: 'green' } }
      expect(response).to redirect_to(root_path)
      message = StatusMessage.where(user: admin_user, message: 'Some message', severity: 'green')
      expect(message).to exist
    end

    it 'requires message and severity parameters' do
      login(admin_user)

      expect do
        post :create, params: { status_message: { message: 'Some message' } }
      end.not_to change(StatusMessage, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Could not create status message: Severity can't be blank")

      expect do
        post :create, params: { status_message: { severity: 'green' } }
      end.not_to change(StatusMessage, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Could not create status message: Message can't be blank")
    end

    context 'non-admin users' do
      before do
        login(user)

        post :create, params: { status_message: { message: 'Some message', severity: 'green' } }
      end

      it 'does not create a status message' do
        expect(response).to redirect_to(root_path)
        message = StatusMessage.where(user: admin_user, message: 'Some message', severity: 'green')
        expect(message).not_to exist
      end
    end

    context 'empty message' do
      before do
        login(admin_user)
        post :create, params: { status_message: { severity: 'green' } }
      end

      it { expect(flash[:error]).to eq("Could not create status message: Message can't be blank") }
    end

    context 'empty severity' do
      before do
        login(admin_user)
        post :create, params: { status_message: { message: 'Some message' } }
      end

      it { expect(flash[:error]).to eq("Could not create status message: Severity can't be blank") }
    end

    context 'that fails at saving the message' do
      before do
        login(admin_user)
        allow_any_instance_of(StatusMessage).to receive(:save).and_return(false)
        post :create, params: { status_message: { message: 'Some message', severity: 'green' } }
      end

      it { expect(flash[:error]).not_to be(nil) }
    end
  end

  describe 'DELETE destroy' do
    let!(:message) { create(:status_message, user: admin_user) }

    it_behaves_like 'require logged in user' do
      let(:method) { :delete }
      let(:action) { :destroy }
      let(:opts) do
        { params: { id: message.id } }
      end
    end

    context 'as an admin' do
      before do
        login(admin_user)
      end

      subject { delete :destroy, params: { id: message.id } }

      it { is_expected.to redirect_to(root_path) }
      it { expect { subject }.to change(StatusMessage, :count).by(-1) }
    end

    context 'non-admin users' do
      before do
        login(user)
      end

      subject { delete :destroy, params: { id: message.id } }

      it { is_expected.to redirect_to(root_path) }
      it { expect { subject }.not_to(change(StatusMessage, :count)) }
    end
  end

  describe 'POST acknowledge' do
    let(:message) { create(:status_message, user: admin_user) }

    it_behaves_like 'require logged in user' do
      let(:method) { :post }
      let(:action) { :acknowledge }
      let(:opts) do
        { params: { id: message.id } }
      end
    end

    context 'when the status message is not yet acknowledged' do
      before do
        allow(RabbitmqBus).to receive(:send_to_bus)
        login(admin_user)
        post :acknowledge, params: { id: message.id }, xhr: true
      end

      it 'collects metrics on rabbitmq' do
        expect(RabbitmqBus).to have_received(:send_to_bus).with('metrics', /user.acknowledged_status/)
      end

      it 'returns a success response' do
        expect(response).to have_http_status(:success)
      end

      it 'shows no error' do
        expect(assigns[:flash]).to be_nil
      end

      it 'the message is acknowledged' do
        expect(message.reload).to be_acknowledged
      end
    end

    context 'when the status message is already acknowledged' do
      before do
        allow(RabbitmqBus).to receive(:send_to_bus)
        login(admin_user)
        message.acknowledge!
        post :acknowledge, params: { id: message.id }, xhr: true
      end

      it 'returns a success response' do
        expect(response).to have_http_status(:success)
      end

      it 'shows no error' do
        expect(flash['error']).to be_nil
      end

      it 'does not collect any metrics' do
        expect(RabbitmqBus).not_to have_received(:send_to_bus).with('metrics', /user.acknowledged_status/)
      end
    end
  end
end
