RSpec.describe RpmlintLogParser, type: :service do
  subject { described_class.new(content: content).call }

  describe '#call' do
    context 'empty file' do
      let(:content) { '' }

      it { expect(subject).to have_attributes(errors: {}, badness: {}, warnings: {}, info: {}) }
    end

    context 'file with no messages' do
      let(:content) { 'hey hey hey' }

      it { expect(subject).to have_attributes(errors: {}, badness: {}, warnings: {}, info: {}) }
    end

    context 'file with some messages' do
      let(:file) { 'rpmlint.log' }
      let(:content) { file_fixture("#{file}") }

      it 'parses the messages' do
        expect(subject).to have_attributes(errors: { 'blueman' => 10 },
                                           badness: { 'blueman' => 90 },
                                           warnings: { 'blueman' => 4 },
                                           info: { 'blueman' => 2 })
      end
    end
  end
end
