RSpec.describe WorkflowVersionValidator do
  let(:fake_model) do
    Struct.new(:workflow_version_number) do
      include ActiveModel::Validations

      validates_with WorkflowVersionValidator
    end
  end

  describe '#validate' do
    subject { fake_model.new(workflow_version_number) }

    context 'with a version number provided in the correct format' do
      let(:workflow_version_number) { '1.1' }

      it { expect(subject).to be_valid }
    end

    context 'with a version number provided in the wrong format' do
      let(:workflow_version_number) { 'wrong_version_scheme' }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq("Malformed workflow version string, please provide the version number in the format: 'major.minor' e.g. '1.1'")
      end
    end

    context 'when no version number is provided' do
      let(:workflow_version_number) { nil }

      it { expect(subject).to be_valid }
    end
  end
end
