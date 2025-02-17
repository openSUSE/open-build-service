RSpec.describe Token::Workflow do
  describe '#call' do
    let(:token_user) { create(:confirmed_user, :with_home, login: 'Iggy') }
    let(:workflow_token) { create(:workflow_token, executor: token_user) }

    context 'with wrong SCM token' do
      let(:yaml_downloader) { instance_double(Workflows::YAMLDownloader) }
      let(:workflow_run) { create(:workflow_run, token: workflow_token, response_url: 'https://example.com') }

      before do
        allow(Workflows::YAMLDownloader).to receive(:new).and_return(yaml_downloader)
        allow(yaml_downloader).to receive(:call).and_raise(Octokit::Unauthorized)
      end

      it "changes the token's triggered_at field and raises an error with a helpful message" do
        expect do
          workflow_token.call({ workflow_run: workflow_run })
        end.to change(workflow_token, :triggered_at).and(raise_error(Token::Errors::SCMTokenInvalid, 'Your SCM token secret is not properly set in your OBS workflow token.' \
                                                                                                     "\nCheck #{described_class::AUTHENTICATION_DOCUMENTATION_LINK}"))
      end
    end

    context 'without validation errors' do
      subject { workflow_token.call(workflow_run: workflow_run) }

      let(:workflow_run) do
        create(:workflow_run, token: workflow_token, scm_vendor: scm_vendor, hook_event: hook_event,
                              request_payload: request_payload, response_url: 'https://example.com')
      end
      let(:scm_vendor) { 'github' }
      let(:hook_event) { 'pull_request' }
      let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }
      let(:yaml_downloader) { Workflows::YAMLDownloader.new(workflow_run, token: workflow_token) }
      let(:yaml_file) { file_fixture('workflows.yml') }
      let(:yaml_to_workflows_service) { Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, token: workflow_token, workflow_run: workflow_run) }
      let(:workflow) do
        Workflow.new(workflow_run: workflow_run, token: workflow_token,
                     workflow_instructions: { steps: [branch_package: { source_project: 'home:Admin', source_package: 'ctris', target_project: 'dev:tools' }] })
      end
      let(:workflows) { [workflow] }

      before do
        # Skipping call since it's tested in the Workflow model
        allow(workflow).to receive(:call).and_return(true)

        allow(Workflows::YAMLDownloader).to receive(:new).with(workflow_run, token: workflow_token).and_return(yaml_downloader)
        allow(yaml_downloader).to receive(:call).and_return(yaml_file)
        allow(Workflows::YAMLToWorkflowsService).to receive(:new).with(yaml_file: yaml_file, token: workflow_token,
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
      subject { workflow_token.call(workflow_run: workflow_run) }

      let(:workflow_run) do
        create(:workflow_run, token: workflow_token, scm_vendor: scm_vendor, hook_event: hook_event,
                              request_payload: request_payload, response_url: 'https://example.com')
      end
      let(:scm_vendor) { 'github' }
      let(:hook_event) { 'pull_request' }
      let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }
      let(:yaml_downloader) { Workflows::YAMLDownloader.new(workflow_run, token: workflow_token) }
      let(:yaml_file) { file_fixture('workflows.yml') }
      let(:yaml_to_workflows_service) { Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, token: workflow_token, workflow_run: workflow_run) }
      let(:workflows) { [Workflow.new(workflow_run: workflow_run, token: workflow_token, workflow_instructions: {})] }

      before do
        allow(Workflows::YAMLDownloader).to receive(:new).with(workflow_run, token: workflow_token).and_return(yaml_downloader)
        allow(yaml_downloader).to receive(:call).and_return(yaml_file)
        allow(Workflows::YAMLToWorkflowsService).to receive(:new).with(yaml_file: yaml_file, token: workflow_token,
                                                                       workflow_run: workflow_run).and_return(yaml_to_workflows_service)
        allow(yaml_to_workflows_service).to receive(:call).and_return(workflows)
      end

      it 'returns the validation errors' do
        expect(subject).to eq(['Steps are mandatory in a workflow', "Documentation for steps: #{WorkflowStepsValidator::DOCUMENTATION_LINK}"])
      end

      it { expect { subject }.to change(workflow_token, :triggered_at) & change(workflow_run, :response_url).to('https://api.github.com') }
    end

    context 'with a ping event' do
      subject { workflow_token.call(workflow_run: workflow_run) }

      let(:workflow_run) do
        create(:workflow_run, token: workflow_token, scm_vendor: scm_vendor, hook_event: hook_event,
                              request_payload: request_payload, response_url: 'https://example.com')
      end
      let(:scm_vendor) { 'github' }
      let(:hook_event) { 'ping' }
      let(:request_payload) { { sender: { url: 'https://api.github.com' } }.to_json }
      let(:workflow) do
        Workflow.new(token: workflow_token, workflow_run: workflow_run,
                     workflow_instructions: { steps: [branch_package: { source_project: 'home:Admin', source_package: 'ctris', target_project: 'dev:tools' }] })
      end
      let(:workflows) { [workflow] }

      before do
        # Skipping call since it's tested in the Workflow model
        allow(workflow).to receive(:call).and_return(true)
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
      let(:workflow_run) do
        create(:workflow_run, token: workflow_token, scm_vendor: 'github', hook_event: 'pull_request',
                              request_payload: request_payload)
      end
      let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

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

    context 'when processing a reportable event' do
      subject { workflow_token.call(workflow_run: workflow_run) }

      let(:scm_vendor) { 'github' }
      let(:hook_event) { 'pull_request' }
      let(:github_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

      let(:workflow_run) do
        create(:workflow_run, token: workflow_token, scm_vendor: scm_vendor, hook_event: hook_event,
                              request_payload: github_payload)
      end

      let(:yaml_downloader) { Workflows::YAMLDownloader.new(workflow_run, token: workflow_token) }
      let(:yaml_file) { file_fixture('workflows.yml') }
      let(:yaml_to_workflows_service) { Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, token: workflow_token, workflow_run: workflow_run) }
      let(:workflow) do
        Workflow.new(token: workflow_token, workflow_run: workflow_run,
                     workflow_instructions: { steps: [branch_package: { source_project: 'home:Admin', source_package: 'ctris', target_project: 'dev:tools' }] })
      end
      let(:workflows) { [workflow] }
      let(:octokit_client) { instance_double(Octokit::Client) }

      before do
        # Skipping call since it's tested in the Workflow model
        allow(workflow).to receive(:call).and_return(true)
        allow(Workflows::YAMLDownloader).to receive(:new).with(workflow_run, token: workflow_token).and_return(yaml_downloader)
        allow(yaml_downloader).to receive(:call).and_return(yaml_file)
        allow(Workflows::YAMLToWorkflowsService).to receive(:new).with(yaml_file: yaml_file, token: workflow_token,
                                                                       workflow_run: workflow_run).and_return(yaml_to_workflows_service)
        allow(yaml_to_workflows_service).to receive(:call).and_return(workflows)
        allow(octokit_client).to receive(:create_status)
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
      end

      it 'returns no validation errors' do
        expect { subject }.to change(SCMStatusReport, :count).by(2)
      end
    end

    context 'when processing a non-reportable event' do
      subject { workflow_token.call(workflow_run: workflow_run) }

      let(:scm_vendor) { 'github' }
      let(:hook_event) { 'pull_request' }
      let(:github_payload) { file_fixture('request_payload_github_pull_request_closed.json').read }

      let(:workflow_run) do
        create(:workflow_run, token: workflow_token, scm_vendor: scm_vendor, hook_event: hook_event,
                              request_payload: github_payload)
      end

      let(:yaml_downloader) { Workflows::YAMLDownloader.new(workflow_run, token: workflow_token) }
      let(:yaml_file) { file_fixture('workflows.yml') }
      let(:yaml_to_workflows_service) { Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, token: workflow_token, workflow_run: workflow_run) }
      let(:workflow) do
        Workflow.new(token: workflow_token, workflow_run: workflow_run,
                     workflow_instructions: { steps: [branch_package: { source_project: 'home:Admin', source_package: 'ctris', target_project: 'dev:tools' }] })
      end
      let(:workflows) { [workflow] }
      let(:octokit_client) { instance_double(Octokit::Client) }

      before do
        # Skipping call since it's tested in the Workflow model
        allow(workflow).to receive(:call).and_return(true)

        allow(Workflows::YAMLDownloader).to receive(:new).with(workflow_run, token: workflow_token).and_return(yaml_downloader)
        allow(yaml_downloader).to receive(:call).and_return(yaml_file)
        allow(Workflows::YAMLToWorkflowsService).to receive(:new).with(yaml_file: yaml_file, token: workflow_token,
                                                                       workflow_run: workflow_run).and_return(yaml_to_workflows_service)
        allow(yaml_to_workflows_service).to receive(:call).and_return(workflows)
        allow(octokit_client).to receive(:create_status)
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
      end

      it 'returns no validation errors' do
        expect { subject }.not_to(change(SCMStatusReport, :count))
      end
    end
  end
end
