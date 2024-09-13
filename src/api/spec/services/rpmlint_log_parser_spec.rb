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
      let(:content) { file_fixture(file.to_s) }

      it 'parses the messages' do
        expect(subject).to have_attributes(errors: { 'ruby2.5-rubygem-bigdecimal' => 10 },
                                           badness: { 'ruby2.5-rubygem-bigdecimal' => 90 },
                                           warnings: { 'ruby2.5-rubygem-bigdecimal' => 4 },
                                           info: { 'ruby2.5-rubygem-bigdecimal' => 2 })
      end
    end
  end
end
