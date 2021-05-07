require 'rails_helper'

RSpec.describe Workflow, type: :model do
  include_context 'a scm payload hash'
  let(:yaml) do
    { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
  end

  subject do
    described_class.new(workflow: yaml, scm_extractor_payload: github_extractor_payload)
  end

  describe 'steps' do
    context 'with supported step' do
      it 'initializes the supported step objects' do
        expect(subject.steps.first).to be_a(Workflow::Step::BranchPackageStep)
      end
    end

    context 'with unsupported step' do
      let(:yaml) do
        { 'steps' => [{ 'unsupported_step' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
      end

      it 'returns an empty array' do
        expect(subject.steps).to be_empty
      end
    end

    context 'with no steps specified' do
      let(:yaml) do
        {}
      end

      it 'returns an empty array' do
        expect(subject.steps).to be_empty
      end
    end
  end
end
