RSpec.describe Webui::Users::CannedResponsesController do
  let(:user) { create(:confirmed_user) }
  let(:title) { 'I agree' }
  let(:decision_type) { nil }
  let(:content) { Faker::Lorem.sentence }

  before do
    login(user)
    Flipper.enable(:canned_responses)

    post :create, params: { canned_response: { title: title, content: content, decision_type: decision_type } }
  end

  describe 'POST create' do
    context 'when content is missing' do
      let(:content) { nil }

      it 'does not create the canned response' do
        expect(flash[:error]).to start_with('Failed to create canned response:')
        expect(CannedResponse.where(title: title)).not_to exist
      end
    end

    context 'when the response is for normal comments' do
      it 'creates the canned response with decision_type nil' do
        expect(flash[:success]).to eq('Canned response successfully created!')
        expect(CannedResponse.where(title: title, decision_type: nil)).to exist
      end
    end

    context 'when the response is for decisions comments' do
      let(:decision_type) { 'favored' }

      it 'creates the canned response with decision_type "favored"' do
        expect(flash[:success]).to eq('Canned response successfully created!')
        expect(CannedResponse.where(title: title, decision_type: 'favored')).to exist
      end
    end
  end
end
