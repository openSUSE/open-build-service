require 'rails_helper'

RSpec.describe Workflow, type: :model do
  include_context 'a scm payload hash'

  let!(:token) { create(:workflow_token) }

  subject do
    described_class.new(workflow_instructions: yaml, scm_extractor_payload: github_extractor_payload, token: token)
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

    context 'with several unsupported steps' do
      let(:yaml) do
        { 'steps' => [{ 'unsupported_step' => {} },
                      { 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } }] }
      end

      it { expect { subject.valid? }.to raise_error("Invalid workflow step definition: 'unsupported_step' is not a supported step") }
    end

    context 'when steps are not provided' do
      let(:yaml) do
        { 'steps' => [{}] }
      end

      it 'raises an exception for non-present steps' do
        expect { subject.valid? }.to raise_error(Token::Errors::InvalidWorkflowStepDefinition,
                                                 'Invalid workflow. Steps are not present.')
      end
    end

    context 'with a supported step but step is empty' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => {} }] }
      end

      it 'raises an exception for non-present instructions' do
        expect { subject.valid? }.to raise_error(Token::Errors::InvalidWorkflowStepDefinition,
                                                 "Invalid workflow step definition: Source project name can't be blank and Source package name can't be blank")
      end
    end

    context 'with a supported step but invalid step configuration' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { source_project: nil,
                                              source_package_fake: 'package' } }] }
      end

      it 'raises an exception for invalid instructions' do
        expect { subject.valid? }.to raise_error(Token::Errors::InvalidWorkflowStepDefinition,
                                                 "Invalid workflow step definition: Source project name can't be blank and Source package name can't be blank")
      end
    end

    # Filters validations

    ['architectures', 'repositories'].each do |filter|
      context "with #{filter} filters having non-valid types" do
        let(:yaml) do
          {
            'filters' => {
              filter => { 'onlyyy' => [{ 'non_valid' => ['ppc'] }, 'x86_64'], 'ignore' => ['i586'] }
            },
            'steps' => [{ 'branch_package' => { source_project: 'project',
                                                source_package: 'package' } }]
          }
        end

        it 'raises a user-friendly error message' do
          expect do
            subject.valid?
          end.to raise_error(Workflow::Errors::UnsupportedWorkflowFilterTypes, "Filters #{filter} have unsupported keys. only and ignore are the only supported keys.")
        end
      end
    end

    context 'with unsupported filters' do
      let(:yaml) do
        {
          'filters' => {
            'unsupported_1' => { 'only' => ['foo'] },
            'unsupported_2' => { 'ignore' => ['bar'] }
          },
          'steps' => [{ 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } }]
        }
      end

      it 'raises a user-friendly error message' do
        expect { subject.valid? }.to raise_error(Workflow::Errors::UnsupportedWorkflowFilters, 'Unsupported filters: unsupported_1 and unsupported_2')
      end
    end

    # Event and Action validations

    context 'When we have a valid combination of SCM events and actions' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
      end
      let(:github_extractor_payload) do
        {
          scm: 'github',
          action: 'opened',
          event: 'pull_request'
        }.with_indifferent_access
      end

      it { expect(subject).to be_valid }
    end

    context 'When we do not have a valid combination of SCM events and actions' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
      end
      let(:github_extractor_payload) do
        {
          scm: 'github',
          action: 'invalid_action',
          event: 'invalid_event'
        }.with_indifferent_access
      end

      it { expect(subject).not_to(be_valid) }
    end
  end
end
