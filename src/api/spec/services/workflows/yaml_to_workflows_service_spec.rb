RSpec.describe Workflows::YAMLToWorkflowsService, type: :service do
  let(:workflow_run_github_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }
  let(:workflow_run_gitlab_payload) { file_fixture('request_payload_gitlab_pull_request_opened.json').read }
  let(:workflows_yml_file) { file_fixture('workflows.yml') }
  let(:token) { create(:workflow_token) }
  let(:scm_vendor) { 'github' }
  let(:hook_event) { 'pull_request' }
  let(:hook_action) { 'opened' }

  let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: scm_vendor, hook_event: hook_event, hook_action: hook_action, request_payload: request_payload) }

  describe '#call' do
    subject do
      Workflows::YAMLToWorkflowsService.new(yaml_file: workflows_yml_file, token: token, workflow_run: workflow_run).call
    end

    context 'it supports many workflows' do
      let(:workflows_yml_file) { file_fixture('multiple_workflows.yml') }
      let(:request_payload) { workflow_run_github_payload }

      it { expect(subject.size).to be(2) }
    end

    context 'with placeholder variables' do
      let(:workflows_yml_file) { file_fixture('multiple_workflows.yml') }
      let(:request_payload) { workflow_run_github_payload }

      it 'maps them to their values from the webhook event payload' do
        expect(subject.first.workflow_instructions).to include(steps: [{ branch_package: { source_project: 'test-project:openSUSE', source_package: 'repo123',
                                                                                           target_project: 'test-target-project' } }])

        expect(subject.second.workflow_instructions).to include(steps: [{ branch_package: { source_project: 'test-project',
                                                                                            source_package: 'test-package:123456789',
                                                                                            target_project: 'test-target-project:PR-1' } }])
      end
    end

    context 'with webhook payload from gitlab' do
      let(:request_payload) { workflow_run_gitlab_payload }
      let(:scm_vendor) { 'gitlab' }
      let(:hook_event) { 'Merge Request Hook' }
      let(:hook_action) { 'open' }

      it 'initializes a workflow object' do
        expect(subject.first).to be_a(Workflow)
      end
    end

    context 'with webhook payload from github' do
      let(:request_payload) { workflow_run_github_payload }

      it 'initializes a workflow object' do
        expect(subject.first).to be_a(Workflow)
      end
    end

    context 'with a invalid workflows.yml' do
      let(:workflows_yml_file) { file_fixture('unparsable_workflows.yml') }
      let(:request_payload) { workflow_run_github_payload }

      it 'raises a user-friendly error' do
        expect { subject }.to raise_error(Token::Errors::WorkflowsYamlNotParsable)
      end
    end

    context 'with invalid placeholder variables' do
      let(:workflows_yml_file) { file_fixture('unparsable_workflows_placeholders.yml') }
      let(:request_payload) { workflow_run_github_payload }

      it 'raises a user-friendly error' do
        expect { subject }.to raise_error(Token::Errors::WorkflowsYamlNotParsable, 'Unable to parse .obs/workflows.yml: malformed format string - %S')
      end
    end
  end
end
