require 'rails_helper'

RSpec.describe Workflows::YAMLToWorkflowsService, type: :service do
  include_context 'a scm payload hash'
  let(:workflows_yml_file) { File.expand_path(Rails.root.join('spec/support/files/workflows.yml')) }

  describe '#call' do
    context 'with webhook payload from gitlab' do
      it 'initializes a workflow object' do
        service = Workflows::YAMLToWorkflowsService.new(yaml_file: workflows_yml_file, scm_extractor_payload: gitlab_extractor_payload)
        expect(service.call.first).to be_a(Workflow)
      end
    end

    context 'with webhook payload from github' do
      it 'initializes a workflow object' do
        service = Workflows::YAMLToWorkflowsService.new(yaml_file: workflows_yml_file, scm_extractor_payload: github_extractor_payload)
        expect(service.call.first).to be_a(Workflow)
      end
    end
  end
end
