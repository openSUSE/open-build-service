require 'rails_helper'

RSpec.describe WorkflowEventFilterValidator do
  describe '#validate' do
    let(:yaml) do
      {
        'steps' => [{ 'branch_package' => {
          'source_project' => 'test-project',
          'source_package' => 'test-package',
          'target_project' => 'test-target-project'
        } }],
        'filters' => filters
      }
    end

    context 'there are no supported filters' do
      let(:filters) { { 'event' => 'foo' } }

      subject { Workflow.new(workflow_instructions: yaml) }

      it 'is not valid and has an error message' do
        expect(subject).not_to(be_valid)
        expect(subject.errors.full_messages.to_sentence).to eql('Workflow filter not supported: foo')
      end
    end

    context 'there are no event filters' do
      let(:filters) { {} }

      subject { Workflow.new(workflow_instructions: yaml) }

      it 'is not valid and has an error message' do
        expect(subject).not_to(be_valid)
        expect(subject.errors.full_messages.to_sentence).to eql('Workflow filter not present')
      end
    end

    context 'the event filter is push' do
      let(:filters) { { 'event' => 'push' } }

      subject { Workflow.new(workflow_instructions: yaml) }

      it 'is valid and has an no message' do
        expect(subject).to be_valid
        expect(subject.errors.full_messages.to_sentence).to be_blank
      end
    end

    context 'the event filter is pull_request' do
      let(:filters) { { 'event' => 'pull_request' } }

      subject { Workflow.new(workflow_instructions: yaml) }

      it 'is valid and has an no message' do
        expect(subject).to be_valid
        expect(subject.errors.full_messages.to_sentence).to be_blank
      end
    end
  end
end
