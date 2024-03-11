RSpec.describe PackageService::FileVerifier do
  let(:file_verifier) { described_class.new(package: package, file_name: file_name, content: content) }
  let!(:project) { create(:project_with_package, name: 'openSUSE:Maintenance', package_name: 'chromium') }

  let(:temp_file) do
    Tempfile.new.tap do |f|
      f << 'Hello World'
      f.close
    end
  end

  after { temp_file.unlink }

  describe '.new' do
    let(:package) { project.packages.first }
    let(:file_name) { 'foo.txt' }
    let(:content) { ActionDispatch::Http::UploadedFile.new(filename: file_name, type: 'text/plain', tempfile: temp_file) }

    context 'content upload file' do
      it { expect { file_verifier }.not_to raise_error }
    end

    context 'content is xml' do
      let(:content) { '<xml></xml>' }

      it { expect { file_verifier }.not_to raise_error }
    end
  end

  describe '.call' do
    let(:package) { project.packages.first }

    context 'invalid constraints' do
      subject { file_verifier.call }

      let(:file_name) { '_constraints' }
      let(:content) { 'illegal' }

      it { expect { subject }.to raise_error(Suse::ValidationError) }
    end

    context 'invalid service file' do
      subject { file_verifier.call }

      let(:file_name) { '_service' }
      let(:content) { 'illegal' }

      it { expect { subject }.to raise_error(Suse::ValidationError) }
    end

    context 'valid uploaded file' do
      subject { file_verifier.call }

      let(:file_name) { 'foo.txt' }
      let(:content) { ActionDispatch::Http::UploadedFile.new(filename: file_name, type: 'text/plain', tempfile: temp_file) }

      it { expect { subject }.not_to raise_error }
    end

    context 'valid uploaded file has the right content' do
      let(:file_name) { 'foo.txt' }
      let(:content) { ActionDispatch::Http::UploadedFile.new(filename: file_name, type: 'text/plain', tempfile: temp_file) }

      before { file_verifier.call }

      it { expect(file_verifier.content).to eq('Hello World') }
    end

    context 'valid service file' do
      subject { file_verifier.call }

      let(:file_name) { '_service' }
      let(:content) do
        <<-XML
        <services>
        <service name="download_files" mode="disabled" />
        </services>
        XML
      end

      it { expect { subject }.not_to raise_error }
    end

    context 'valid service file has the right content' do
      let(:file_name) { '_service' }
      let(:content) do
        <<-XML
          <services>
          <service name="download_files" mode="disabled" />
          </services>
        XML
      end

      before { file_verifier.call }

      it { expect(file_verifier.content).to eq(content) }
    end
  end
end
