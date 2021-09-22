require 'rails_helper'

RSpec.describe Workflows::YAMLToWorkflowsService, type: :service do
  let(:github_extractor_payload) do
    {
      scm: 'github',
      repo_url: 'https://github.com/openSUSE/open-build-service',
      commit_sha: '387185b7df2b572377712994116c19cd7dd13150',
      pr_number: 123,
      source_branch: 'test_branch',
      target_branch: 'master',
      action: 'opened',
      repository_full_name: 'openSUSE/open-build-service',
      event: 'pull_request'
    }
  end
  let(:gitlab_extractor_payload) do
    {
      scm: 'gitlab',
      object_kind: 'merge_request',
      http_url: 'http://example.com/gitlabhq/gitlab-test.git',
      commit_sha: 'da1560886d4f094c3e6c9ef40349f7d38b5d27d7',
      pr_number: 123,
      source_branch: 'test_branch',
      target_branch: 'master',
      action: 'open',
      project_id: 1,
      path_with_namespace: 'gitlabhq/gitlab-test',
      event: 'Merge Request Hook'
    }
  end
  let(:workflows_yml_file) { File.expand_path(Rails.root.join('spec/support/files/workflows.yml')) }
  let(:token) { create(:workflow_token) }

  describe '#call' do
    subject do
      Workflows::YAMLToWorkflowsService.new(yaml_file: workflows_yml_file, scm_webhook: ScmWebhook.new(payload: payload), token: token).call
    end

    context 'it supports many workflows' do
      let(:workflows_yml_file) { File.expand_path(Rails.root.join('spec/support/files/multiple_workflows.yml')) }
      let(:payload) { github_extractor_payload }

      it { expect(subject.size).to be(2) }
    end

    context 'with webhook payload from gitlab' do
      let(:payload) { gitlab_extractor_payload }

      it 'initializes a workflow object' do
        expect(subject.first).to be_a(Workflow)
      end
    end

    context 'with webhook payload from github' do
      let(:payload) { github_extractor_payload }

      it 'initializes a workflow object' do
        expect(subject.first).to be_a(Workflow)
      end
    end

    context 'with a invalid workflows.yml' do
      let(:workflows_yml_file) { File.expand_path(Rails.root.join('spec/support/files/unparsable_workflows.yml')) }
      let(:payload) { github_extractor_payload }

      it 'raises a user-friendly error' do
        expect { subject }.to raise_error(Token::Errors::WorkflowsYamlNotParsable)
      end
    end
  end
end
