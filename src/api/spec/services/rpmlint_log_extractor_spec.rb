RSpec.describe RpmlintLogExtractor, type: :service do
  let(:parameters) { ActionController::Parameters.new(project: 'home:user1', package: 'package1', repository: 'repo1', architecture: 'arch1') }

  subject { described_class.new(parameters).call }

  describe '#call' do
    context 'no rpmlint.log file available since error exceeds allowed badness level' do
      before do
        Flipper.enable(:request_show_redesign)
        allow(Backend::Api::BuildResults::Binaries).to receive(:rpmlint_log)
          .with('home:user1', 'package1', 'repo1', 'arch1')
          .and_raise(Backend::NotFoundError, 'rpmlint.log: No such file or directory')
        allow(Backend::Api::BuildResults::Binaries).to receive(:files)
          .with('home:user1', 'repo1', 'arch1', 'package1')
          .and_return("<binarylist><binary filename=\"ctris-0.42.1-8.1.src.rpm\" size=\"26772\" mtime=\"1704975490\"/></binarylist>\n")
        allow(Backend::Api::BuildResults::Binaries).to receive(:file)
          .with('home:user1', 'repo1', 'arch1', 'package1', '_log')
          .and_return(file_fixture('rpmlint_log_extractor_log').read)
      end

      it 'extracts the summary from the build log file' do
        expect(subject).to eq(file_fixture('rpmlint_log_extractor_expected').read)
      end
    end
  end
end
