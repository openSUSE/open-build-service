RSpec.describe Backend::File, :vcr do
  subject { TestBackendFile.new(name: 'fake_filename', somefile: somefile_txt_url) }

  let(:user) { create(:user, :with_home, login: 'user') }
  let(:package_with_file) { create(:package_with_file, name: 'package_with_files', project: user.home_project) }
  let(:fake_file) { file_fixture('hello.txt') }
  let(:somefile_txt_url) { "/source/#{user.home_project_name}/#{package_with_file.name}/somefile.txt" }

  # Needed because full_path is only defined in subclasses of Backend::File
  let(:backend_file_class) do
    Class.new(described_class) do
      attr_accessor :somefile

      def full_path(_query)
        Addressable::URI.encode(somefile)
      end
    end
  end

  before do
    stub_const('TestBackendFile', backend_file_class)
  end

  describe '#initialize' do
    context 'without any param' do
      subject { Backend::File.new }

      it { expect(subject.name).to be_blank }
      it { expect(subject.response).to be_empty }
    end

    context 'with a name' do
      it { expect(subject.name).to eq('fake_filename') }
      it { expect(subject.response).to be_empty }
    end
  end

  describe '#file=' do
    let(:input_stream) { fake_file.open }

    before do
      subject.file = input_stream
    end

    after do
      input_stream.close
    end

    it { expect(subject.file.class).to eq(Tempfile) }
    it { expect(File.read(subject.file.path)).to eq("hello\n") }
  end

  describe '#file_from_path' do
    context 'with a well formed filename' do
      before do
        subject.file_from_path(fake_file.to_s)
      end

      it { expect(subject.file.class).to eq(File) }
      it { expect(subject.response[:type]).to eq('text/plain') }
      it { expect(subject.response[:status]).to eq(200) }
      it { expect(subject.response[:size]).to eq(6) }
      it { expect(File.read(subject.file.path)).to eq("hello\n") }
    end

    context 'with a file without extension' do
      before do
        subject.file_from_path(file_fixture('hello_world').to_s)
      end

      it { expect(subject.file.class).to eq(File) }
      it { expect(subject.response[:type]).to be_nil }
      it { expect(subject.response[:status]).to eq(200) }
      it { expect(subject.response[:size]).to eq(13) }
      it { expect(File.read(subject.file.path)).to eq("hello world!\n") }
    end
  end

  describe '#file' do
    context 'with a file already loaded' do
      before do
        subject.file_from_path(fake_file.to_s)
      end

      it { expect(subject.file.class).to eq(File) }
      it { expect(subject.response[:type]).to eq('text/plain') }
      it { expect(subject.response[:status]).to eq(200) }
      it { expect(subject.response[:size]).to eq(6) }
      it { expect(File.read(subject.file.path)).to eq("hello\n") }
    end

    context 'without a file already loaded' do
      context 'and an invalid object' do
        subject { Backend::File.new }

        it { expect(subject.file).to be_nil }
        it { is_expected.not_to be_valid }
      end

      context 'and a valid object' do
        before do
          login user

          subject.file
        end

        it { expect(subject.file.class).to eq(Tempfile) }
        it { expect(subject.response[:type]).to eq('application/octet-stream') }
        it { expect(subject.response[:status]).to eq('200') }
        it { expect(subject.response[:size]).to be > 0 }
        it { expect(File.read(subject.file.path)).not_to be_empty }
      end
    end

    context 'with a backend error' do
      before do
        allow(Backend::Connection).to receive(:get).and_raise(StandardError, 'message')
      end

      it { expect(subject.file).to be_nil }

      it 'left the object invalid if errors are present' do
        subject.file
        expect(subject).not_to be_valid
      end

      it 'displays error messages' do
        subject.file
        expect(subject.errors.full_messages).to contain_exactly('Content message')
      end
    end
  end

  describe '#to_s' do
    context 'with an existing file in the backend' do
      subject { Backend::File.new(name: 'fake_filename') }

      before do
        login user

        subject.file
      end

      it { expect(subject.to_s.class).to eq(String) }
      it { expect(subject.to_s).not_to be_empty }
    end

    context 'without an existing file in the backend' do
      let(:somefile_txt_url) { "/source/#{user.home_project_name}/fake_package/somefile.txt" }

      before do
        login user

        subject.file
      end

      it { expect(subject.content).to be_nil }
    end
  end

  describe '#reload' do
    context 'with an existing file in the backend' do
      let!(:previous_content) { subject.content }

      before do
        login user

        subject.save({}, 'hello') # Change the content of the file
      end

      it { expect(File.read(subject.reload.path)).not_to eq(previous_content) }
    end
  end

  describe '#save!' do
    context 'with a string as content' do
      let!(:previous_content) { subject.content }

      before do
        subject.save!({}, 'hello') # Change the content of the file with a string
      end

      it { expect(File.read(subject.file.path)).not_to eq(previous_content) }
      it { expect(File.read(subject.file.path)).to eq('hello') }
    end

    context 'with a file as content' do
      let!(:previous_content) { subject.content }

      before do
        subject.file = fake_file.open
        subject.save!
      end

      it { expect(File.read(subject.file.path)).not_to eq(previous_content) }
      it { expect(File.read(subject.file.path)).to eq("hello\n") }
    end
  end

  describe '#save' do
    context 'with a backend error' do
      before do
        somefile_txt_url # create the package before we break put
        allow(Backend::Connection).to receive(:put).and_raise(StandardError, 'message')
      end

      it 'left the object invalid if errors are present' do
        subject.save({}, 'hello')
        expect(subject).not_to be_valid
      end

      it 'displays error messages' do
        subject.save({}, 'hello')
        expect(subject.errors.full_messages).to contain_exactly('Content message')
      end
    end
  end

  describe '#destroy!' do
    before do
      subject.destroy!
    end

    it { expect { Backend::Connection.get(somefile_txt_url) }.to raise_error(Backend::NotFoundError) }
    it { is_expected.to be_frozen }
    it { expect(subject.response[:type]).to eq('text/xml') }
    it { expect(subject.response[:status]).to eq('200') }
    it { expect(subject.response[:size]).to be > 0 }
  end

  describe '#destroy' do
    context 'with a backend error' do
      before do
        allow(Backend::Connection).to receive(:delete).and_raise(StandardError, 'message')

        subject.file

        subject.destroy
      end

      it { is_expected.not_to be_frozen }
      it { is_expected.not_to be_valid }
      it { expect(subject.errors.full_messages).to contain_exactly('Content message') }
      it { expect(subject.response[:type]).to eq('application/octet-stream') }
      it { expect(subject.response[:status]).to eq('200') }
      it { expect(subject.response[:size]).to be > 0 }
    end
  end

  describe '.query_from_list' do
    let(:hash) { { a: 1, b: 2 } }
    let(:hash_with_nil_values) { { a: 1, b: 2, c: nil, d: 6 } }
    let(:key_list) { [:a] }

    it { expect(Backend::File.query_from_list({})).to be_empty }
    it { expect(Backend::File.query_from_list(hash)).to eq('?a=1&b=2') }
    it { expect(Backend::File.query_from_list(hash_with_nil_values)).to eq('?a=1&b=2&c=&d=6') }
    it { expect(Backend::File.query_from_list(hash, key_list)).to eq('?a=1') }
  end
end
