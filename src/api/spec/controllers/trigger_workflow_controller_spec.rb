require 'rails_helper'

RSpec.describe TriggerWorkflowController do
  render_views

  describe 'POST :create' do
    context 'workflows.yml do not exist' do
      let(:octokit_client) { instance_double(Octokit::Client) }
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { create(:workflow_token, executor: create(:confirmed_user)) }
      let(:github_payload) do
        {
          action: 'opened',
          pull_request: {
            head: {
              repo: { full_name: 'username/test_repo' }
            },
            base: {
              ref: 'main',
              repo: { full_name: 'rubhanazeem/hello_world' }
            }
          },
          number: 4,
          sender: { url: 'https://api.github.com' }
        }
      end

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:content).and_return({ download_url: 'https://google.com' })
        allow(Down).to receive(:download).and_raise(Down::Error, 'Beep Boop, something is wrong')
        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'
        post :create, body: github_payload.to_json
      end

      it { expect(response).to have_http_status(:not_found) }

      it "displays a user-friendly error message in the response's body" do
        expect(response.body).to include(".obs/workflows.yml could not be downloaded from the SCM branch/commit main.\nIs the configuration file in the expected place? " \
                                         "Check #{Workflows::YAMLDownloader::DOCUMENTATION_LINK}\nBeep Boop, something is wrong")
      end

      it { expect(WorkflowRun.count).to eq(1) }
      it { expect(WorkflowRun.last.status).to eq('fail') }
      it { expect(response.body).to include(WorkflowRun.last.response_body) }
    end

    context 'token different type' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { create(:service_token, executor: create(:confirmed_user)) }

      let(:github_payload) do
        {
          action: 'opened',
          pull_request: {
            head: {
              repo: { full_name: 'username/test_repo' }
            },
            base: {
              ref: 'main',
              repo: { full_name: 'rubhanazeem/hello_world' }
            }
          },
          number: 4,
          sender: { url: 'https://api.github.com' }
        }
      end

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'

        post :create, body: github_payload.to_json
      end

      it { expect(response).to have_http_status(:forbidden) }
      it { expect(response.body).to include('Please use workflow tokens only') }
    end

    context 'token is invalid' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(nil)
        post :create, params: { format: :json }
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'scm event is invalid' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { build_stubbed(:workflow_token, executor: build_stubbed(:confirmed_user)) }

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)

        post :create, params: { format: :json }
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(WorkflowRun.count).to eq(0) }
    end

    context 'scm action is invalid' do
      let(:octokit_client) { instance_double(Octokit::Client) }
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { build_stubbed(:workflow_token, executor: build_stubbed(:confirmed_user)) }
      let(:github_payload) do
        {
          action: 'assigned',
          pull_request: {
            head: {
              repo: { full_name: 'username/test_repo' }
            },
            base: {
              ref: 'main',
              repo: { full_name: 'rubhanazeem/hello_world' }
            }
          },
          number: 4,
          sender: { url: 'https://api.github.com' }
        }
      end

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:content).and_return({ download_url: 'https://google.com' })
        allow(Down).to receive(:download).and_raise(Down::Error, 'Beep Boop, something is wrong')
        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'
        post :create, body: github_payload.to_json
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(WorkflowRun.count).to eq(0) }
    end

    context 'the action unsupported' do
      let(:octokit_client) { instance_double(Octokit::Client) }
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { create(:workflow_token, executor: create(:confirmed_user)) }
      let(:github_payload) do
        {}
      end

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'create'
        post :create, body: github_payload.to_json
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(WorkflowRun.count).to eq(1) }

      it 'returns an error message in the response body' do
        expect(response.body).to eql("<status code=\"bad_request\">\n  <summary>This SCM event is not supported</summary>\n</status>\n")
      end
    end

    context 'scm payload is invalid' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { create(:workflow_token, executor: create(:confirmed_user)) }

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'
      end

      context 'payload is empty' do
        before do
          post :create, body: ''
        end

        it { expect(response).to have_http_status(:bad_request) }
      end

      context 'payload can not be parsed' do
        before do
          post :create, body: 'some_unparseable_json }{'
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end

    context 'validation errors happening when triggering the token' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { build_stubbed(:workflow_token, executor: build_stubbed(:confirmed_user)) }
      let(:github_payload) do
        {
          action: 'opened',
          pull_request: {
            head: {
              repo: { full_name: 'username/test_repo' }
            },
            base: {
              ref: 'main',
              repo: { full_name: 'rubhanazeem/hello_world' }
            }
          },
          number: 4,
          sender: { url: 'https://api.github.com' }
        }
      end

      before do
        allow(token).to receive(:call).and_return(['Event not supported.', 'Workflow steps are not present'])

        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)

        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'

        post :create, body: github_payload.to_json
      end

      it { expect(response).to have_http_status(:bad_request) }

      it 'includes validation errors in the response body' do
        expect(response.body).to include('Event not supported. and Workflow steps are not present')
      end

      it { expect(WorkflowRun.count).to eq(1) }
      it { expect(WorkflowRun.last.status).to eq('fail') }
      it { expect(response.body).to include(WorkflowRun.last.response_body) }
    end

    context 'no validation errors' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { build_stubbed(:workflow_token, executor: build_stubbed(:confirmed_user)) }
      let(:github_payload) do
        {
          action: 'opened',
          pull_request: {
            head: {
              repo: { full_name: 'username/test_repo' }
            },
            base: {
              ref: 'main',
              repo: { full_name: 'rubhanazeem/hello_world' }
            }
          },
          number: 4,
          sender: { url: 'https://api.github.com' }
        }
      end

      before do
        allow(token).to receive(:call).and_return([])

        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)

        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'

        post :create, body: github_payload.to_json
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response.content_type).to eq('application/xml; charset=utf-8') }

      it { expect(WorkflowRun.count).to eq(1) }
      it { expect(WorkflowRun.last.status).to eq('success') }
      it { expect(response.body).to include('Ok') }
    end

    context 'the SCM is unsupported' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { build_stubbed(:workflow_token, executor: build_stubbed(:confirmed_user)) }
      let(:scm_payload) do
        { super: 'duper' }
      end

      before do
        allow(token).to receive(:call).and_return([])

        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)

        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'

        post :create, body: scm_payload.to_json
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(response.content_type).to eq('application/xml; charset=utf-8') }

      it 'returns an error message in the response body' do
        expect(response.body).to include('Only GitHub, GitLab and Gitea are supported. ' \
                                         'Could not find the required HTTP request headers X-GitHub-Event, X-Gitlab-Event or X-Gitea-Event')
      end
    end
  end
end
