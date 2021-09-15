require 'rails_helper'

RSpec.describe Workflow, type: :model do
  include_context 'a scm payload hash'

  let!(:token) { create(:workflow_token) }

  subject do
    described_class.new(workflow_instructions: yaml, scm_webhook: ScmWebhook.new(payload: github_extractor_payload), token: token)
  end

  describe '#steps' do
    let(:yaml) do
      { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
    end

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
                      { 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } }] }
      end

      it 'returns an array with only one item' do
        expect(subject.steps.count).to be 1
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

  describe '#filters' do
    ['architectures', 'repositories'].each do |filter|
      context "with #{filter} filters having valid values" do
        let(:yaml) do
          {
            'filters' => {
              filter => { 'only' => ['s390x', 12.3, 567], 'ignore' => ['i586'] }
            }
          }
        end

        it "returns #{filter} filters with 'only' having precedence over 'ignore'" do
          expect(subject.filters).to eq({ "#{filter}": { only: ['s390x', 12.3, 567] } })
        end
      end
    end

    context 'without filters' do
      let(:yaml) do
        {}
      end

      it 'returns nothing' do
        expect(subject.filters).to eq({})
      end
    end
  end

  describe '#valid' do
    before do
      subject.valid?
    end

    # Steps validations

    context 'with a supported step' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
      end

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

    context 'with unsupported steps' do
      let(:yaml) do
        { 'steps' => [{ 'unsupported_step_1' => {} },
                      { 'unsupported_step_2' => {} },
                      { 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } }] }
      end

      it 'sets validation errors' do
        expect(subject.errors.full_messages).to match_array(
          ['Invalid workflow step definition: unsupported_step_1 and unsupported_step_2 are not supported steps']
        )
      end
    end

    context 'when steps are not provided' do
      let(:yaml) do
        { 'steps' => [{}] }
      end

      it 'sets validation errors' do
        expect(subject.errors.full_messages).to match_array(['Invalid workflow. Steps are not present.'])
      end
    end

    context 'with a supported step but step is empty' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => {} }] }
      end

      it 'sets validation errors' do
        expect(subject.errors.full_messages).to match_array(
          ["Invalid workflow step definition: The 'source_project' key is missing, The 'source_package' key is missing, \
Source project name can't be blank, and Source package name can't be blank"]
        )
      end
    end

    context 'with a supported step but invalid step configuration' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { source_project: nil,
                                              source_package: nil } }] }
      end

      it 'sets validation errors' do
        expect(subject.errors.full_messages).to match_array(
          ["Invalid workflow step definition: Source project name can't be blank and Source package name can't be blank"]
        )
      end
    end

    context 'with a combination of unsupported steps and invalid step configuration' do
      let(:yaml) do
        { 'steps' => [{ 'unsupported_step_1' => {} },
                      { 'branch_package' => { source_project: nil } }] }
      end

      it 'sets validation errors' do
        expect(subject.errors.full_messages).to match_array(
          ["Invalid workflow step definition: unsupported_step_1 is not a supported step, The 'source_package' key is missing, \
Source project name can't be blank, and Source package name can't be blank"]
        )
      end
    end
  end
end
