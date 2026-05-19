RSpec.describe CannedResponsesController do
  render_views

  let(:user) { create(:confirmed_user) }

  before do
    login user
    Flipper.enable(:canned_responses)
  end

  describe 'GET #index' do
    let!(:canned_responses) { create_list(:canned_response, 3, user: user) }

    before { get :index, format: :xml }

    it { expect(response).to have_http_status(:success) }

    it 'returns all canned responses for the current user' do
      canned_responses.each do |canned_response|
        expect(response.body).to have_css('canned_responses > canned_response > title', text: canned_response.title)
      end
    end

    it 'does not include canned responses from other users' do
      other_user = create(:confirmed_user)
      other_response = create(:canned_response, user: other_user)
      get :index, format: :xml
      expect(response.body).to have_no_css("canned_response[id='#{other_response.id}']")
    end
  end

  describe 'GET #show' do
    let!(:canned_response) { create(:canned_response, user: user) }

    before { get :show, params: { id: canned_response.id }, format: :xml }

    it { expect(response).to have_http_status(:success) }

    it 'returns the requested canned response' do
      expect(response.body).to have_css('canned_response > title', text: canned_response.title)
      expect(response.body).to have_css('canned_response > content', text: canned_response.content)
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { format: :xml }, body: request_xml }

    context 'with valid XML' do
      let(:request_xml) do
        <<~XML
          <canned_response>
            <title>Thank you</title>
            <content>Thank you for your contribution!</content>
          </canned_response>
        XML
      end

      before { subject }

      it { expect(response).to have_http_status(:success) }
      it { expect(CannedResponse.last.title).to eq('Thank you') }
      it { expect(CannedResponse.last.content).to eq('Thank you for your contribution!') }
      it { expect(CannedResponse.last.user).to eq(user) }
    end

    context 'with decision_type' do
      let(:request_xml) do
        <<~XML
          <canned_response>
            <title>Cleared</title>
            <content>This report has been cleared.</content>
            <decision_type>cleared</decision_type>
          </canned_response>
        XML
      end

      before { subject }

      it { expect(CannedResponse.last.decision_type).to eq('cleared') }
    end

    context 'with missing title' do
      let(:request_xml) do
        <<~XML
          <canned_response>
            <content>Some content</content>
          </canned_response>
        XML
      end

      before { subject }

      it { expect(response).to have_http_status(:bad_request) }
    end
  end

  describe 'PUT #update' do
    subject { put :update, params: { id: canned_response.id, format: :xml }, body: request_xml }

    let!(:canned_response) { create(:canned_response, user: user) }
    let(:request_xml) do
      <<~XML
        <canned_response>
          <title>Updated title</title>
          <content>Updated content</content>
        </canned_response>
      XML
    end

    before { subject }

    it { expect(response).to have_http_status(:success) }
    it { expect(canned_response.reload.title).to eq('Updated title') }
    it { expect(canned_response.reload.content).to eq('Updated content') }
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: canned_response.id }, format: :xml }

    let!(:canned_response) { create(:canned_response, user: user) }

    it { expect(subject).to have_http_status(:success) }
    it { expect { subject }.to change(CannedResponse, :count).by(-1) }
  end
end
