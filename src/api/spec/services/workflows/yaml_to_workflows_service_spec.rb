RSpec.describe Workflows::YAMLToWorkflowsService, type: :service do
  let(:workflow_run_github_payload) do
    {
      action: 'opened',
      number: 123,
      pull_request: {
        base: {
          repo: {
            full_name: 'openSUSE/open-build-service'
          }
        },
        head: {
          sha: '387185b7df2b572377712994116c19cd7dd13150'
        }
      }
    }.to_json
  end
  let(:workflow_run_gitlab_payload) do
    {
      object_kind: 'merge_request',
      after: 'da1560886d4f094c3e6c9ef40349f7d38b5d27d7',
      object_attributes: {
        target: {
          path_with_namespace: 'gitlabhq/gitlab-test'
        }
      }
    }.to_json
  end
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
        expect(subject.first.workflow_instructions).to include(steps: [{ branch_package: { source_project: 'test-project:openSUSE', source_package: 'open-build-service',
                                                                                           target_project: 'test-target-project' } }])

        expect(subject.second.workflow_instructions).to include(steps: [{ branch_package: { source_project: 'test-project',
                                                                                            source_package: 'test-package:387185b7df2b572377712994116c19cd7dd13150',
                                                                                            target_project: 'test-target-project:PR-123' } }])
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
