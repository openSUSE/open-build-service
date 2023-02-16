require 'rails_helper'

RSpec.describe WorkflowFiltersValidator do
  let(:fake_model) do
    Struct.new(:workflow_instructions, :scm_webhook) do
      include ActiveModel::Validations

      # To prevent the error "ArgumentError: Class name cannot be blank. You need to supply a name argument when anonymous class given"
      def self.name
        'FakeModel'
      end

      validates_with WorkflowFiltersValidator
    end
  end

  describe '#validate' do
    let(:scm_webhook) { SCMWebhook.new(payload: {}) }

    subject { fake_model.new(workflow_instructions, scm_webhook) }

    context 'without the filters key' do
      let(:workflow_instructions) { {} }

      it { is_expected.to be_valid }
    end

    context 'without filters' do
      let(:workflow_instructions) { { filters: {} } }

      it { is_expected.to be_valid }
    end

    context 'with unsupported filters' do
      let(:workflow_instructions) { { filters: { something: {}, else: {}, branches: {} } } }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('Filters something and else are unsupported and ' \
                                                               "Documentation for filters: #{described_class::DOCUMENTATION_LINK}")
      end
    end

    context 'with unsupported filter values' do
      let(:workflow_instructions) { { filters: { event: [], branches: { only: [], something: [] } } } }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('Filter event only supports a string value, ' \
                                                               "Filters branches have unsupported values, 'only' and 'ignore' are the only supported values., and " \
                                                               "Documentation for filters: #{described_class::DOCUMENTATION_LINK}")
      end
    end

    context 'with multiple filters' do
      let(:workflow_instructions) { { filters: [{ event: 'push' }] } }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('Filters definition is wrong and ' \
                                                               "Documentation for filters: #{described_class::DOCUMENTATION_LINK}")
      end
    end

    context 'with supported filters and filter values' do
      let(:workflow_instructions) { { filters: { event: 'something', branches: { only: [] } } } }

      it { is_expected.to be_valid }
    end

    context 'with a branches filter for a tag push event' do
      let(:workflow_instructions) { { filters: { event: 'tag_push', branches: { only: [] } } } }
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'push', ref: 'refs/tags/1.0.0' }) }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('Filters for branches are not supported for the tag push event and ' \
                                                               "Documentation for filters: #{described_class::DOCUMENTATION_LINK}")
      end
    end
  end
end
