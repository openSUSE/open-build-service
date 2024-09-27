RSpec.describe RpmlintLogExtractor, type: :service do
  subject { described_class.new(parameters).call }

  let(:parameters) { ActionController::Parameters.new(project: 'home:user1', package: 'package1', repository: 'repo1', architecture: 'arch1') }
  let(:invalid_byte_sequence_in_utf8) { "this is an invalid byte sequence \xED" }

  before do
    Flipper.enable(:request_show_redesign)
  end

  describe '#call' do
    context 'rpmlint.log file is available in the backend with an invalid byte sequence' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:rpmlint_log)
          .with('home:user1', 'package1', 'repo1', 'arch1')
          .and_return(invalid_byte_sequence_in_utf8)
      end

      it 'returns the text with the invalid byte sequence corrected' do
        expect(subject).to eq('this is an invalid byte sequence �')
      end
    end

    context 'no rpmlint.log file available in the backend' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:rpmlint_log)
          .with('home:user1', 'package1', 'repo1', 'arch1')
          .and_raise(Backend::NotFoundError, 'rpmlint.log: No such file or directory')
      end

      context 'no _log file available since error exceeds allowed badness level and has invalid byte sequence' do
        before do
          allow(Backend::Api::BuildResults::Binaries).to receive(:file)
            .with('home:user1', 'repo1', 'arch1', 'package1', '_log')
            .and_return(file_fixture('rpmlint_log_extractor_log').read)
        end

        it 'extracts the summary from the build log file' do
          expect(subject).to eq(file_fixture('rpmlint_log_extractor_expected').read)
        end
      end

      context 'no _log file available and no rpmlint mark available' do
        before do
          allow(Backend::Api::BuildResults::Binaries).to receive(:file)
            .with('home:user1', 'repo1', 'arch1', 'package1', '_log')
            .and_return(file_fixture('rpmlint_log_extractor_log_without_mark').read)
        end

        it 'returns empty results' do
          expect(subject).to be_nil
        end
      end

      context 'when the _log file contains invalid byte sequences in UTF-8 without mark' do
        before do
          allow(Backend::Api::BuildResults::Binaries).to receive(:file)
            .with('home:user1', 'repo1', 'arch1', 'package1', '_log')
            .and_return(invalid_byte_sequence_in_utf8)
        end

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end
    end
  end
end
