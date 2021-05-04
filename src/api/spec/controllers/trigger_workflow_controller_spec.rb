require 'rails_helper'

RSpec.describe TriggerWorkflowController, type: :controller do
  let(:user) { create(:confirmed_user, login: 'foo') }
  let(:token) { Token::Workflow.create(user: user) }
  let(:token_extractor_instance) { instance_double(::TriggerControllerService::TokenExtractor) }

  describe 'POST :create' do
    context 'scm event is invalid' do
      before do
        allow(::TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)

        post :create, params: { format: :json }
      end

      it { expect(response).to have_http_status(:bad_request) }
    end

    context 'scm payload is invalid' do
      before do
        allow(::TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'
      end

      context 'payload is empty' do
        before do
          post :create, params: { format: :json }
        end

        it { expect(response).to have_http_status(:bad_request) }
      end

      context 'payload can not be parsed' do
        before do
          post :create, params: { format: :json }, body: 'some_unparseable_json }{'
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end
end
