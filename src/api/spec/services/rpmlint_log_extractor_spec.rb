RSpec.describe RpmlintLogExtractor, type: :service do
  subject { described_class.new(parameters).call }

  let(:parameters) { ActionController::Parameters.new(project: 'home:user1', package: 'package1', repository: 'repo1', architecture: 'arch1') }

  before do
    Flipper.enable(:request_show_redesign)
    allow(Backend::Api::BuildResults::Binaries).to receive(:rpmlint_log)
      .with('home:user1', 'package1', 'repo1', 'arch1')
      .and_raise(Backend::NotFoundError, 'rpmlint.log: No such file or directory')
  end

  describe '#call' do
    context 'no rpmlint.log file available since error exceeds allowed badness level' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:file)
          .with('home:user1', 'repo1', 'arch1', 'package1', '_log')
          .and_return(file_fixture('rpmlint_log_extractor_log').read)
      end

      it 'extracts the summary from the build log file' do
        expect(subject).to eq(file_fixture('rpmlint_log_extractor_expected').read)
      end
    end

    context 'when the rpmlint log contains invalid byte sequences in UTF-8' do
      let(:invalid_byte_sequence_in_utf8) { "this is an invalid byte sequence \xED" }

      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:file)
          .with('home:user1', 'repo1', 'arch1', 'package1', '_log')
          .and_return(invalid_byte_sequence_in_utf8)
      end

      it 'extracts the summary from the build log file' do
        expect(subject).to eq('this is an invalid byte sequence �')
      end
    end
  end
end
