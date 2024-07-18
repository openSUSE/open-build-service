RSpec.describe Webui::StatusMessagesController do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  describe 'GET new' do
    it { is_expected.to use_after_action(:verify_authorized) }
  end

  describe 'POST create' do
    it { is_expected.to use_after_action(:verify_authorized) }

    it 'create a news item' do
      login(admin_user)

      post :create, params: { status_message: { message: 'Some message', severity: 'green' } }
      expect(response).to redirect_to(news_items_path)
      message = StatusMessage.where(user: admin_user, message: 'Some message', severity: 'green')
      expect(message).to exist
    end

    it 'requires message and severity parameters' do
      login(admin_user)

      expect do
        post :create, params: { status_message: { message: 'Some message' } }
      end.not_to change(StatusMessage, :count)
      expect(response).to redirect_to(news_items_path)
      expect(flash[:error]).to eq("Could not create news item: Severity can't be blank")

      expect do
        post :create, params: { status_message: { severity: 'green' } }
      end.not_to change(StatusMessage, :count)
      expect(response).to redirect_to(news_items_path)
      expect(flash[:error]).to eq("Could not create news item: Message can't be blank")
    end

    context 'non-admin users' do
      before do
        login(user)

        post :create, params: { status_message: { message: 'Some message', severity: 'green' } }
      end

      it 'is not authorized to create a status message' do
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq('Requires staff privileges')
        message = StatusMessage.where(user: admin_user, message: 'Some message', severity: 'green')
        expect(message).not_to exist
      end
    end

    context 'empty message' do
      before do
        login(admin_user)
        post :create, params: { status_message: { severity: 'green' } }
      end

      it { expect(flash[:error]).to eq("Could not create news item: Message can't be blank") }
    end

    context 'empty severity' do
      before do
        login(admin_user)
        post :create, params: { status_message: { message: 'Some message' } }
      end

      it { expect(flash[:error]).to eq("Could not create news item: Severity can't be blank") }
    end

    context 'that fails at saving the message' do
      before do
        login(admin_user)
        allow_any_instance_of(StatusMessage).to receive(:save).and_return(false)
        post :create, params: { status_message: { message: 'Some message', severity: 'green' } }
      end

      it { expect(flash[:error]).not_to be_nil }
    end
  end

  describe 'DELETE destroy' do
    let!(:message) { create(:status_message, user: admin_user) }

    it { is_expected.to use_after_action(:verify_authorized) }

    context 'as an admin' do
      subject { delete :destroy, params: { id: message.id } }

      before do
        login(admin_user)
      end

      it { is_expected.to redirect_to(news_items_path) }
      it { expect { subject }.to change(StatusMessage, :count).by(-1) }
    end

    context 'non-admin users' do
      subject { delete :destroy, params: { id: message.id } }

      before do
        login(user)
      end

      it 'is not authorized to delete a status message' do
        expect(subject).to redirect_to(root_path)
        expect(flash[:error]).to eq('Requires staff privileges')
      end

      it { expect { subject }.not_to(change(StatusMessage, :count)) }
    end
  end

  describe 'POST acknowledge' do
    let(:message) { create(:status_message, user: admin_user) }

    it { is_expected.to use_after_action(:verify_authorized) }

    context 'when the news item is not yet acknowledged' do
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

    context 'when the news item is already acknowledged' do
      before do
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
    end
  end
end
