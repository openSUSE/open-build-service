require 'rails_helper'

RSpec.describe Workflow, type: :model do
  include_context 'a scm payload hash'
  let(:yaml) do
    { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
  end

  subject do
    described_class.new(workflow: yaml, scm_extractor_payload: github_extractor_payload, token: create(:workflow_token))
  end

  describe '#steps' do
    context 'with a supported step' do
      it 'initializes the supported step objects' do
        expect(subject.steps.first).to be_a(Workflow::Step::BranchPackageStep)
      end
    end

    context 'with several supported steps' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } },
                      { 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } }] }
      end

      it 'returns an array with two items' do
        expect(subject.steps.count).to be 2
      end
    end

    context 'with one unsupported step' do
      let(:yaml) do
        { 'steps' => [{ 'unsupported_step' => {} },
                      { 'branch_package' => {} }] }
      end

      it 'returns an array with no items' do
        expect { subject }.to raise_error("Invalid workflow step definition: 'unsupported_step' is not a supported step")
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

  describe '#valid' do
    context 'with a supported step' do
      it { expect(subject).to be_valid }
    end

    context 'with several supported steps' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } },
                      { 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } }] }
      end

      it { expect(subject).to be_valid }
    end

    context 'with several unsupported steps' do
      let(:yaml) do
        { 'steps' => [{ 'unsupported_step' => {} },
                      { 'branch_package' => {} }] }
      end

      it { expect { subject }.to raise_error("Invalid workflow step definition: 'unsupported_step' is not a supported step") }
    end
  end

  describe '#errors' do
    context 'with a supported step' do
      it { expect(subject.errors).to be_empty }
    end

    context 'with several supported steps' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } },
                      { 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } }] }
      end

      it { expect(subject.errors).to be_empty }
    end

    context 'with several unsupported steps' do
      let(:yaml) do
        { 'steps' => [{ 'unsupported_step' => {} },
                      { 'unsupported_step' => {} },
                      { 'branch_package' => {} }] }
      end

      it 'has several errors' do
        expect { subject }.to raise_error("Invalid workflow step definition: 'unsupported_step' is not a supported step and 'unsupported_step' is not a supported step")
      end
    end
  end
end
