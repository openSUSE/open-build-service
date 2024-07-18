RSpec.describe StatusMessagesController do
  render_views

  let(:user) { create(:confirmed_user) }

  before do
    login user
  end

  describe 'GET #show' do
    let!(:status_message) { create(:status_message, user: user) }

    before { get :show, params: { id: status_message.id }, format: :xml }

    it { expect(response).to have_http_status(:success) }

    it 'returns the requested status message' do
      expect(response.body).to have_css('status_message > message', text: status_message.message)
    end
  end

  describe 'GET #index' do
    let!(:status_messages) { create_list(:status_message, 3) }

    before { get :index, format: :xml }

    it { expect(response).to have_http_status(:success) }

    it 'returns all status messages' do
      status_messages.each do |status_message|
        expect(response.body).to have_css('status_messages[count=3] > status_message > message', text: status_message.message)
      end
    end
  end

  describe '#create' do
    subject { post :create, params: { format: :xml }, body: request_xml }

    let(:request_xml) do
      <<~XML
        <status_message>
          <message>New message was sent!</message>
          <severity>green</severity>
          <scope>all_users</scope>
        </status_message>
      XML
    end
    let(:admin) { create(:admin_user) }

    before do
      login admin
      subject
    end

    it { expect(StatusMessage.last.message).to eq('New message was sent!') }
  end

  describe '#update' do
    subject { post :update, params: { id: status_message.id, format: :xml }, body: request_xml }

    let(:request_xml) do
      <<~XML
        <status_message>
          <message>Updated message was sent!</message>
          <severity>green</severity>
          <scope>all_users</scope>
        </status_message>
      XML
    end
    let(:admin) { create(:admin_user) }
    let!(:status_message) { create(:status_message, user: user) }

    before do
      login admin
      subject
    end

    it { expect(StatusMessage.last.message).to eq('Updated message was sent!') }
  end

  describe '#destroy' do
    subject { delete :destroy, params: { id: status_message.id }, format: :xml }

    let!(:status_message) { create(:status_message, user: user) }
    let(:admin) { create(:admin_user) }

    before do
      login admin
    end

    it { expect(subject).to have_http_status(:success) }
    it { expect { subject }.to change(StatusMessage, :count).by(-1) }
  end
end
