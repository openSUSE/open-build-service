require 'rails_helper'

RSpec.describe WorkflowStepsValidator do
  let(:fake_model) do
    Struct.new(:steps, :workflow_steps) do
      include ActiveModel::Validations

      validates_with WorkflowStepsValidator
    end
  end

  describe '#validate' do
    subject { fake_model.new(steps, workflow_steps) }

    context 'without steps' do
      let(:steps) { [] }
      let(:workflow_steps) { [] }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('Workflow steps are not present')
      end
    end

    context 'with unsupported steps' do
      let(:steps) { [] }
      let(:workflow_steps) { [{ unsupported_step1: {} }, { unsupported_step2: {} }] }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('The provided workflow steps are unsupported')
      end
    end

    context 'with unsupported and supported steps' do
      let(:step_instructions) { { source_project: 'project', source_package: 'package', target_project: 'target_project' } }
      let(:steps) { [Workflow::Step::BranchPackageStep.new(step_instructions: step_instructions)] }
      let(:workflow_steps) { [unsupported_step: {}, branch_package: step_instructions] }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq("The following workflow steps are unsupported: 'unsupported_step'")
      end
    end

    context 'with unsupported and invalid steps' do
      let(:step_instructions) { { source_project: 'project' } }
      let(:steps) { [Workflow::Step::BranchPackageStep.new(step_instructions: step_instructions)] }
      let(:workflow_steps) { [unsupported_step: {}, branch_package: step_instructions] }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq("The following workflow steps are unsupported: 'unsupported_step' and " \
                                                               "The 'source_package' key is missing and The 'target_project' key is missing")
      end
    end
  end
end
