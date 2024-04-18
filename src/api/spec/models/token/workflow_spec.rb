RSpec.describe Token::Workflow do
  describe '#call' do
    let(:token_user) { create(:confirmed_user, :with_home, login: 'Iggy') }
    let(:workflow_token) { create(:workflow_token, executor: token_user) }
    let(:workflow_run) { create(:workflow_run, token: workflow_token, response_url: 'https://example.com') }

    context 'without a payload' do
      it do
        expect do
          workflow_token.call({ workflow_run: workflow_run,
                                scm_webhook: SCMWebhook.new(payload: {}) })
        end.to raise_error(Token::Errors::MissingPayload, 'A payload is required').and(change(workflow_token, :triggered_at))
      end
    end

    context 'with wrong SCM token' do
      let(:yaml_downloader) { instance_double(Workflows::YAMLDownloader) }

      before do
        allow(Workflows::YAMLDownloader).to receive(:new).and_return(yaml_downloader)
        allow(yaml_downloader).to receive(:call).and_raise(Octokit::Unauthorized)
      end

      it "changes the token's triggered_at field and raises an error with a helpful message" do
        expect do
          workflow_token.call({ workflow_run: workflow_run,
                                scm_webhook: SCMWebhook.new(payload: { something: 123 }) })
        end.to change(workflow_token, :triggered_at).and(raise_error(Token::Errors::SCMTokenInvalid, 'Your SCM token secret is not properly set in your OBS workflow token.' \
                                                                                                     "\nCheck #{described_class::AUTHENTICATION_DOCUMENTATION_LINK}"))
      end
    end

    context 'without validation errors' do
      subject { workflow_token.call(workflow_run: workflow_run, scm_webhook: scm_extractor.call) }

      let(:scm) { 'github' }
      let(:event) { 'pull_request' }
      let(:github_payload) do
        {
          action: 'opened',
          pull_request: {
            head: {
              ref: 'my_branch',
              repo: { full_name: 'username/test_repo' },
              sha: '12345678'
            },
            base: {
              ref: 'main',
              repo: { full_name: 'openSUSE/open-build-service' }
            }
          },
          number: '4',
          sender: { url: 'https://api.github.com' }
        }
      end
      let(:github_extractor_payload) do
        {
          scm: 'github',
          event: 'pull_request',
          api_endpoint: 'https://api.github.com',
          commit_sha: '12345678',
          pr_number: '4',
          source_branch: 'my_branch',
          target_branch: 'main',
          action: 'opened',
          source_repository_full_name: 'username/test_repo',
          target_repository_full_name: 'openSUSE/open-build-service'
        }
      end
      let(:scm_extractor) { TriggerControllerService::SCMExtractor.new(scm, event, github_payload) }
      let(:scm_webhook) { SCMWebhook.new(payload: github_extractor_payload) }
      let(:yaml_downloader) { Workflows::YAMLDownloader.new(scm_webhook.payload, token: workflow_token) }
      let(:yaml_file) { file_fixture('workflows.yml') }
      let(:yaml_to_workflows_service) { Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, scm_webhook: scm_webhook, token: workflow_token, workflow_run: workflow_run) }
      let(:workflow) do
        Workflow.new(scm_webhook: scm_webhook, token: workflow_token,
                     workflow_instructions: { steps: [branch_package: { source_project: 'home:Admin', source_package: 'ctris', target_project: 'dev:tools' }] })
      end
      let(:workflows) { [workflow] }

      before do
        # Skipping call since it's tested in the Workflow model
        allow(workflow).to receive(:call).and_return(true)

        allow(TriggerControllerService::SCMExtractor).to receive(:new).with(scm, event, github_payload).and_return(scm_extractor)
        allow(scm_extractor).to receive(:call).and_return(scm_webhook)
        allow(Workflows::YAMLDownloader).to receive(:new).with(scm_webhook.payload, token: workflow_token).and_return(yaml_downloader)
        allow(yaml_downloader).to receive(:call).and_return(yaml_file)
        allow(Workflows::YAMLToWorkflowsService).to receive(:new).with(yaml_file: yaml_file, scm_webhook: scm_webhook, token: workflow_token,
                                                                       workflow_run: workflow_run).and_return(yaml_to_workflows_service)
        allow(yaml_to_workflows_service).to receive(:call).and_return(workflows)
        allow(SCMStatusReporter).to receive(:new).and_return(proc { true })
      end

      it 'returns no validation errors' do
        expect(subject).to eq([])
      end

      it { expect { subject }.to change(workflow_token, :triggered_at) & change(workflow_run, :response_url).to('https://api.github.com') }

      it 'sends the initial report twice' do
        subject
        expect(SCMStatusReporter).to have_received(:new).twice
      end
    end

    context 'with validation errors' do
      subject { workflow_token.call(workflow_run: workflow_run, scm_webhook: scm_extractor.call) }

      let(:scm) { 'github' }
      let(:event) { 'wrong_event' }
      let(:github_payload) do
        {
          action: 'opened',
          pull_request: {
            head: {
              ref: 'my_branch',
              repo: { full_name: 'username/test_repo' },
              sha: '12345678'
            },
            base: {
              ref: 'main',
              repo: { full_name: 'openSUSE/open-build-service' }
            }
          },
          number: '4',
          sender: { url: 'https://api.github.com' }
        }
      end
      let(:github_extractor_payload) do
        {
          scm: 'github',
          event: event,
          api_endpoint: 'https://api.github.com'
        }
      end
      let(:scm_extractor) { TriggerControllerService::SCMExtractor.new(scm, event, github_payload) }
      let(:scm_webhook) { SCMWebhook.new(payload: github_extractor_payload) }
      let(:yaml_downloader) { Workflows::YAMLDownloader.new(scm_webhook.payload, token: workflow_token) }
      let(:yaml_file) { file_fixture('workflows.yml') }
      let(:yaml_to_workflows_service) { Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, scm_webhook: scm_webhook, token: workflow_token, workflow_run: workflow_run) }
      let(:workflows) { [Workflow.new(scm_webhook: scm_webhook, token: workflow_token, workflow_instructions: {})] }

      before do
        allow(TriggerControllerService::SCMExtractor).to receive(:new).with(scm, event, github_payload).and_return(scm_extractor)
        allow(scm_extractor).to receive(:call).and_return(scm_webhook)
        allow(Workflows::YAMLDownloader).to receive(:new).with(scm_webhook.payload, token: workflow_token).and_return(yaml_downloader)
        allow(yaml_downloader).to receive(:call).and_return(yaml_file)
        allow(Workflows::YAMLToWorkflowsService).to receive(:new).with(yaml_file: yaml_file, scm_webhook: scm_webhook, token: workflow_token,
                                                                       workflow_run: workflow_run).and_return(yaml_to_workflows_service)
        allow(yaml_to_workflows_service).to receive(:call).and_return(workflows)
      end

      it 'returns the validation errors' do
        expect(subject).to eq(['Event not supported.', 'Steps are mandatory in a workflow', "Documentation for steps: #{WorkflowStepsValidator::DOCUMENTATION_LINK}"])
      end

      it { expect { subject }.to change(workflow_token, :triggered_at) & change(workflow_run, :response_url).to('https://api.github.com') }
    end

    context 'with a ping event' do
      subject { workflow_token.call(workflow_run: workflow_run, scm_webhook: scm_extractor.call) }

      let(:scm) { 'github' }
      let(:event) { 'ping' }
      let(:github_payload) { { sender: { url: 'https://api.github.com' } } }
      let(:github_extractor_payload) do
        {
          scm: 'github',
          event: 'ping',
          api_endpoint: 'https://api.github.com'
        }
      end
      let(:scm_extractor) { TriggerControllerService::SCMExtractor.new(scm, event, github_payload) }
      let(:scm_webhook) { SCMWebhook.new(payload: github_extractor_payload) }
      let(:workflow) do
        Workflow.new(scm_webhook: scm_webhook, token: workflow_token,
                     workflow_instructions: { steps: [branch_package: { source_project: 'home:Admin', source_package: 'ctris', target_project: 'dev:tools' }] })
      end
      let(:workflows) { [workflow] }

      before do
        # Skipping call since it's tested in the Workflow model
        allow(workflow).to receive(:call).and_return(true)

        allow(TriggerControllerService::SCMExtractor).to receive(:new).with(scm, event, github_payload).and_return(scm_extractor)
        allow(scm_extractor).to receive(:call).and_return(scm_webhook)
        allow(SCMStatusReporter).to receive(:new).and_return(proc { true })
      end

      it 'returns before checking for validation errors' do
        expect(subject).to be_empty
      end

      it { expect { subject }.to change(workflow_token, :triggered_at).and(change(workflow_run, :response_url).to('https://api.github.com')) }

      it 'returns early with one report' do
        subject
        expect(SCMStatusReporter).to have_received(:new).once
      end
    end

    context 'validates presence of either workflow configuration path or url' do
      let(:workflow_token_a) { build(:workflow_token, workflow_configuration_path: nil) }
      let(:workflow_token_b) { build(:workflow_token, workflow_configuration_path: nil, workflow_configuration_url: 'https://example.com/subdir/config_file.yml') }
      let(:workflow_token_c) { build(:workflow_token, workflow_configuration_path: 'subdir/config_file.yml', workflow_configuration_url: nil) }

      before do
        # For URL validation to work, we have to make sure to have the url return a successful response
        stub_request(:get, 'https://example.com/subdir/config_file.yml')
      end

      it { expect(workflow_token_a).not_to be_valid }
      it { expect(workflow_token_b).to be_valid }
      it { expect(workflow_token_c).to be_valid }
    end

    context 'validates existence of the workflow configuration url' do
      # Correct URL
      let(:workflow_token_a) { build(:workflow_token, workflow_configuration_path: nil, workflow_configuration_url: 'https://example.com/subdir/config_file.yml') }
      # Wrong schema
      let(:workflow_token_b) { build(:workflow_token, workflow_configuration_path: nil, workflow_configuration_url: 'htt://example.com/subdir/config_file.yml') }
      # Wrong URL syntax
      let(:workflow_token_c) { build(:workflow_token, workflow_configuration_path: nil, workflow_configuration_url: 'https://@@example.com/subdir/config_file.yml') }
      # Not resolvable (no such tld)
      let(:workflow_token_d) { build(:workflow_token, workflow_configuration_path: nil, workflow_configuration_url: 'https://example.foo/subdir/config_file.yml') }
      # Not found on the server
      let(:workflow_token_e) { build(:workflow_token, workflow_configuration_path: nil, workflow_configuration_url: 'https://example.com/subdir') }

      before do
        # For URL validation to work, we have to make sure to have the url return an appropriate response for the scenario
        stub_request(:get, 'https://example.com/subdir/config_file.yml')
        stub_request(:get, 'https://example.com/subdir').to_return(status: 404)
      end

      it { expect(workflow_token_a).to be_valid }
      it { expect(workflow_token_b).not_to be_valid }
      it { expect(workflow_token_c).not_to be_valid }
      it { expect(workflow_token_d).not_to be_valid }
      it { expect(workflow_token_e).not_to be_valid }
    end
  end
end
