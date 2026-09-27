require 'rails_helper'

RSpec.describe Workflow do
  let(:user) { create(:confirmed_user, :with_home) }
  let(:token) { create(:workflow_token, executor: user) }
  let(:workflow_run) { create(:workflow_run, token: token) }

  describe 'Malforming payload verification after fix' do
    context 'when branches filter is a string instead of an array' do
      let(:yaml) do
        {
          filters: {
            branches: {
              only: 'master' # Malformed: should be an array
            }
          },
          steps: [
            { branch_package: { source_project: 'test', source_package: 'pkg', target_project: 'tgt' } }
          ]
        }
      end
      let(:request_payload) { { pull_request: { base: { ref: 'master' } } }.to_json }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token, request_payload: request_payload) }

      subject { described_class.new(workflow_instructions: yaml, token: token, workflow_run: workflow_run) }

      it 'does not crash and matches the branch' do
        expect { subject.send(:branch_matches_branches_only_filter?) }.not_to raise_error
        expect(subject.send(:branch_matches_branches_only_filter?)).to be_truthy
      end
      
      it 'reports a validation error but does not crash' do
        expect(subject.valid?).to be_falsey
        expect(subject.errors[:filter]).to include(/branches filter definition is wrong/)
      end
    end

    context 'when steps entry is a string instead of a hash' do
      let(:yaml) do
        {
          steps: [
            'invalid_step_entry' # Malformed: should be a hash
          ]
        }
      end

      subject { described_class.new(workflow_instructions: yaml, token: token, workflow_run: workflow_run) }

      it 'does not crash in #steps and returns empty array' do
        expect { subject.steps }.not_to raise_error
        expect(subject.steps).to be_empty
      end

      it 'reports a validation error' do
        expect(subject.valid?).to be_falsey
        expect(subject.errors[:steps]).to include(/provided in the workflow are unsupported/)
      end
    end
    
    context 'when configure_repositories repositories is a string' do
      let(:yaml_instructions) do
        {
          project: 'test-project',
          repositories: 'malformed' # Should be an array
        }
      end
      
      let(:step) { Workflow::Step::ConfigureRepositories.new(step_instructions: yaml_instructions, token: token, workflow_run: workflow_run) }
      
      it 'does not crash and reports a validation error' do
        expect { step.valid? }.not_to raise_error
        expect(step.valid?).to be_falsey
        expect(step.errors[:base]).to include(/configure_repositories step: All repositories must have/)
      end
    end
  end
end
