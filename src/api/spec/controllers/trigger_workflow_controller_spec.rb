require 'rails_helper'

RSpec.describe TriggerWorkflowController, type: :controller, beta: true do
  let(:user) { create(:confirmed_user, :in_beta, login: 'foo') }
  let(:token) { Token::Workflow.create(user: user) }
  let(:token_extractor_instance) { instance_double(::TriggerControllerService::TokenExtractor) }
  let(:github_payload) do
    {
      action: 'opened',
      pull_request: {
        head: {
          repo: {
            full_name: 'username/test_repo'
          }
        },
        base: {
          ref: 'main',
          repo: {
            full_name: 'rubhanazeem/hello_world'
          }
        }
      },
      number: 4,
      sender: {
        url: 'https://api.github.com'
      }
    }
  end

  render_views

  describe 'POST :create' do
    context 'workflows.yml do not exist' do
      let(:octokit_client) { instance_double(Octokit::Client) }
      let(:token_extractor_instance) { instance_double(::TriggerControllerService::TokenExtractor) }

      before do
        allow(::TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:content).and_return({ download_url: 'https://google.com' })
        allow(Down).to receive(:download).and_raise(Down::Error, 'Beep Boop, something is wrong')
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'
        post :create, params: { format: :json }, body: github_payload.to_json
      end

      it { expect(response).to have_http_status(:not_found) }

      it "displays a user-friendly error message in the response's body" do
        expect(response.body).to include('.obs/workflows.yml could not be downloaded from the SCM branch main: Beep Boop, something is wrong')
      end
    end

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
