RSpec.describe TriggerWorkflowController do
  render_views

  describe 'POST :create' do
    context 'token is not enabled' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { create(:workflow_token, enabled: false, executor: create(:confirmed_user)) }

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        request.headers['ACCEPT'] = '*/*'

        post :create
      end

      it { expect(response).to have_http_status(:forbidden) }
      it { expect(response.body).to include('This token is not enabled.') }
    end

    context 'workflows.yml do not exist' do
      let(:octokit_client) { instance_double(Octokit::Client) }
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { create(:workflow_token, executor: create(:confirmed_user)) }
      let(:github_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:content).and_raise(Octokit::NotFound)
        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'
        post :create, body: github_payload
      end

      it { expect(response).to have_http_status(:not_found) }

      it "displays a user-friendly error message in the response's body" do
        expect(response.body).to include("<status code=\"non_existent_workflows_file\">\n  <summary>.obs/workflows.yml could not be downloaded from the SCM branch/commit master: Octokit::NotFound</summary>\n</status>\n")
      end

      it { expect(WorkflowRun.count).to eq(1) }
      it { expect(WorkflowRun.last.status).to eq('fail') }
      it { expect(response.body).to include(WorkflowRun.last.response_body) }
    end

    context 'token different type' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { create(:service_token, executor: create(:confirmed_user)) }

      let(:github_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'

        post :create, body: github_payload
      end

      it { expect(response).to have_http_status(:forbidden) }
      it { expect(response.body).to include('Please use workflow tokens only') }
    end

    context 'token is invalid' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(nil)
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'
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
      let(:github_payload) { file_fixture('request_payload_github_pull_request_assigned.json').read }

      before do
        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:content).and_return({ content: Base64.encode64('Test content') })
        allow(Down).to receive(:download).and_raise(Down::Error, 'Beep Boop, something is wrong')
        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'
        post :create, body: github_payload
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

      it 'simply ignores the unsupported event' do
        expect(response).to have_http_status(:ok)
        expect(response.body).to eql("<status code=\"ok\">\n  <summary>Ok</summary>\n  <data name=\"info\">Hook event unsupported 'create'</data>\n</status>\n")
      end

      it { expect(WorkflowRun.count).to eq(0) }
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
        it { expect(response.body).to eql("<status code=\"unknown\">\n  <summary>Request payload can not be parsed as JSON</summary>\n</status>\n") }
      end
    end

    context 'validation errors happening when triggering the token' do
      let(:token_extractor_instance) { instance_double(TriggerControllerService::TokenExtractor) }
      let(:token) { build_stubbed(:workflow_token, executor: build_stubbed(:confirmed_user)) }
      let(:github_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

      before do
        allow(token).to receive(:call).and_return(['Event not supported.', 'Workflow steps are not present'])

        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)

        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'

        post :create, body: github_payload
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
      let(:github_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

      before do
        allow(token).to receive(:call).and_return([])

        allow(TriggerControllerService::TokenExtractor).to receive(:new).and_return(token_extractor_instance)
        allow(token_extractor_instance).to receive(:call).and_return(token)

        request.headers['ACCEPT'] = '*/*'
        request.headers['CONTENT_TYPE'] = 'application/json'
        request.headers['HTTP_X_GITHUB_EVENT'] = 'pull_request'

        post :create, body: github_payload
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response.content_type).to eq('application/xml; charset=utf-8') }

      it { expect(WorkflowRun.count).to eq(1) }
      it { expect(WorkflowRun.last.status).to eq('success') }
      it { expect(WorkflowRun.last.repository_full_name).to eq('iggy/hello_world') }
      it { expect(WorkflowRun.last.hook_event).to eq('pull_request') }
      it { expect(WorkflowRun.last.hook_action).to eq('opened') }
      it { expect(WorkflowRun.last.scm_vendor).to eq('github') }
      it { expect(WorkflowRun.last.generic_event_type).to eq('pull_request') }
      it { expect(WorkflowRun.last.event_source_name).to eq('1') }
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
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to eql("<status code=\"unknown\">\n  <summary>Scm vendor unsupported 'unknown'</summary>\n</status>\n")
      end
    end
  end
end
