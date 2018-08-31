require 'rails_helper'

RSpec.describe StatusMessagesController, type: :controller do
  render_views

  let(:user) { create(:confirmed_user) }
  let(:status_message) { create(:status_message) }

  before do
    login user
  end

  describe 'GET #show' do
    subject! { get :show, params: { id: status_message.id }, format: :xml }

    it { is_expected.to have_http_status(:success) }
    it 'returns the requested status message' do
      assert_select 'status_messages[count=1]' do
        assert_select 'message', status_message.message
      end
    end
  end

  describe 'GET #index' do
    let!(:status_messages) { create_list(:status_message, 3) }

    subject! { get :index, format: :xml }

    it { is_expected.to have_http_status(:success) }
    it 'returns all status messages' do
      assert_select 'status_messages[count=3]' do
        status_messages.each do |status_message|
          assert_select 'message', status_message.message
        end
      end
    end
  end

  describe '#create' do
    let(:request_xml) do
      <<~XML
        <status_messages>
          <message severity="1">New message was sent!</message>
        </status_messages>
      XML
    end

    context 'when user is not admin' do
      subject! { post :create, body: request_xml, format: :xml }

      it { is_expected.to have_http_status(:forbidden) }
      it "responds with a 'permission_denied' status" do
        assert_select 'status[code=permission_denied]' do
          assert_select 'summary', 'message(s) cannot be created, you have not sufficient permissions'
        end
      end
    end

    context 'when requester is admin' do
      let(:admin) { create(:admin_user) }

      before do
        login admin
      end

      subject! { post :create, body: request_xml, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it 'responds with the created message' do
        assert_select 'status_messages' do
          assert_select 'message', 'New message was sent!'
        end
      end
      it { expect(StatusMessage.last.message).to eq('New message was sent!') }
    end
  end

  describe '#destroy' do
    context 'when user is not admin' do
      subject! { delete :destroy, params: { id: status_message.id }, format: :xml }

      it { is_expected.to have_http_status(:forbidden) }
      it { expect(status_message.deleted_at).to be_nil }
      it "responds with a 'permission_denied' status" do
        assert_select 'status[code=permission_denied]' do
          assert_select 'summary', 'message cannot be deleted, you have not sufficient permissions'
        end
      end
    end

    context 'when requester is admin' do
      let(:admin) { create(:admin_user) }

      before do
        login admin
      end

      subject! { delete :destroy, params: { id: status_message.id }, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it { expect(status_message.reload.deleted_at).not_to be_nil }
    end
  end
end
