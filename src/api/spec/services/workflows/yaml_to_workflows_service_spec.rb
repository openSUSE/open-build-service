require 'rails_helper'

RSpec.describe Workflows::YAMLToWorkflowsService, type: :service do
  include_context 'a scm payload hash'
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
