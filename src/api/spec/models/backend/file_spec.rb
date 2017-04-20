require 'rails_helper'
# WARNING: If you change #file_exists or #has_file test make sure
# you uncomment the next line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Backend::File, vcr: true do
  let(:user) { create(:user, login: 'user') }
  let(:fake_filename) { 'fake_filename' }
  let(:backend_file_without_name) { described_class.new }
  let(:backend_file_with_name) { described_class.new(name: fake_filename) }
  let(:package_with_file) { create(:package_with_file, name: 'package_with_files', project: user.home_project) }
  let(:fake_file) do
    Tempfile.open([fake_filename, '.txt']) do |file|
      file.write("hello")
      file
    end
  end
  let(:fake_file_without_extension) do
    Tempfile.open(fake_filename) do |file|
      file.write("hello world!")
      file
    end
  end
  let(:somefile_txt_url) { "/source/#{user.home_project_name}/#{package_with_file.name}/somefile.txt" }
  let(:mock_full_path) do
    # Needed because full_path is only defined in subclasses of Backend::File
    allow_any_instance_of(Backend::File).to receive(:full_path) do
      URI.encode(somefile_txt_url)
    end
  end

  describe '#initialize' do
    context 'without any param' do
      subject { backend_file_without_name }

      it { expect(subject.name).to be_blank }
      it { expect(subject.response).to be_empty }
    end

    context 'with a name' do
      subject { backend_file_with_name }

      it { expect(subject.name).to eq(fake_filename) }
      it { expect(subject.response).to be_empty }
    end
  end

  describe '#file=' do
    subject { backend_file_with_name }

    before do
      @input_stream = File.open(fake_file.path)
      subject.file = @input_stream
    end

    after do
      @input_stream.close
    end

    it { expect(subject.file.class).to eq(Tempfile) }
    it { expect(File.open(subject.file.path).read).to eq("hello") }
  end

  describe '#file_from_path' do
    subject { backend_file_with_name }

    context 'with a well formed filename' do
      before do
        subject.file_from_path(fake_file.path)
      end

      it { expect(subject.file.class).to eq(File) }
      it { expect(subject.response[:type]).to eq("text/plain") }
      it { expect(subject.response[:status]).to eq(200) }
      it { expect(subject.response[:size]).to eq(5) }
      it { expect(File.open(subject.file.path).read).to eq("hello") }
    end

    context 'with a file without extension' do
      before do
        subject.file_from_path(fake_file_without_extension.path)
      end

      it { expect(subject.file.class).to eq(File) }
      it { expect(subject.response[:type]).to be_nil }
      it { expect(subject.response[:status]).to eq(200) }
      it { expect(subject.response[:size]).to eq(12) }
      it { expect(File.open(subject.file.path).read).to eq("hello world!") }
    end
  end

  describe '#file' do
    context 'with a file already loaded' do
      subject { backend_file_with_name }

      before do
        subject.file_from_path(fake_file.path)
      end

      it { expect(subject.file.class).to eq(File) }
      it { expect(subject.response[:type]).to eq("text/plain") }
      it { expect(subject.response[:status]).to eq(200) }
      it { expect(subject.response[:size]).to eq(5) }
      it { expect(File.open(subject.file.path).read).to eq("hello") }
    end

    context 'without a file already loaded' do
      context 'and an invalid object' do
        subject { backend_file_without_name }

        it { expect(subject.file).to be_nil }
        it { expect(subject.valid?).to be_falsy }
      end

      context 'and a valid object' do
        subject { backend_file_with_name }

        before do
          login user

          mock_full_path

          subject.file
        end

        it { expect(subject.file.class).to eq(Tempfile) }
        it { expect(subject.response[:type]).to eq("application/octet-stream") }
        it { expect(subject.response[:status]).to eq("200") }
        it { expect(subject.response[:size]).to be > 0 }
        it { expect(File.open(subject.file.path).read).not_to be_empty }
      end
    end

    context 'with a backend error' do
      subject { backend_file_with_name }

      before do
        allow(Backend::Connection).to receive(:get).and_raise(StandardError, 'message')

        mock_full_path
      end

      it { expect(subject.file).to be_nil }

      it "left the object invalid if errors are present" do
        subject.file
        expect(subject.valid?).to be_falsy
      end

      it "it will have error messages" do
        subject.file
        expect(subject.errors.full_messages).to match_array(['Content message'])
      end
    end
  end

  describe '#to_s' do
    context 'with an existing file in the backend' do
      subject { backend_file_with_name }

      before do
        login user

        mock_full_path

        subject.file
      end

      it { expect(subject.to_s.class).to eq(String) }
      it { expect(subject.to_s).not_to be_empty }
    end

    context 'without an existing file in the backend' do
      let(:somefile_txt_url) { "/source/#{user.home_project_name}/fake_package/somefile.txt" }

      subject { backend_file_with_name }

      before do
        login user

        mock_full_path

        subject.file
      end

      it { expect(subject.to_s).to be_nil }
    end
  end

  describe '#reload' do
    context 'with an existing file in the backend' do
      subject { backend_file_with_name }

      before do
        login user

        mock_full_path

        @previous_content = subject.to_s
        subject.save({}, 'hello') # Change the content of the file
      end

      it { expect(File.open(subject.reload.path).read).not_to eq(@previous_content) }
    end
  end

  describe '#save!' do
    context 'with a string as content' do
      subject { backend_file_with_name }

      before do
        mock_full_path

        @previous_content = subject.to_s
        subject.save!({}, 'hello') # Change the content of the file with a string
      end

      it { expect(File.open(subject.file.path).read).not_to eq(@previous_content) }
      it { expect(File.open(subject.file.path).read).to eq('hello') }
    end

    context 'with a file as content' do
      subject { backend_file_with_name }

      before do
        mock_full_path

        @previous_content = subject.to_s

        subject.file = File.open(fake_file.path)
        subject.save!
      end

      it { expect(File.open(subject.file.path).read).not_to eq(@previous_content) }
      it { expect(File.open(subject.file.path).read).to eq('hello') }
    end
  end

  describe '#save' do
    context 'with a backend error' do
      subject { backend_file_with_name }

      before do
        allow(Backend::Connection).to receive(:put).and_raise(StandardError, 'message')

        mock_full_path
      end

      it "left the object invalid if errors are present" do
        subject.save({}, 'hello')
        expect(subject.valid?).to be_falsy
      end

      it "it will have error messages" do
        subject.save({}, 'hello')
        expect(subject.errors.full_messages).to match_array(['Content message'])
      end
    end
  end

  describe '#destroy!' do
    subject { backend_file_with_name }

    before do
      mock_full_path

      subject.destroy!
    end

    it { expect{ Backend::Connection.get(somefile_txt_url) }.to raise_error(ActiveXML::Transport::NotFoundError) }
    it { expect(subject.frozen?).to be_truthy }
    it { expect(subject.response[:type]).to eq('text/xml') }
    it { expect(subject.response[:status]).to eq("200") }
    it { expect(subject.response[:size]).to be > 0 }
  end

  describe '#destroy' do
    context 'with a backend error' do
      subject { backend_file_with_name }

      before do
        allow(Backend::Connection).to receive(:delete).and_raise(StandardError, 'message')

        mock_full_path

        subject.file

        subject.destroy
      end

      it { expect(subject.frozen?).to be_falsy }
      it { expect(subject.valid?).to be_falsy }
      it { expect(subject.errors.full_messages).to match_array(['Content message']) }
      it { expect(subject.response[:type]).to eq("application/octet-stream") }
      it { expect(subject.response[:status]).to eq("200") }
      it { expect(subject.response[:size]).to be > 0 }
    end
  end

  describe '.query_from_list' do
    let(:hash) { {a: 1, b: 2} }
    let(:hash_with_nil_values) { {a: 1, b: 2, c: nil, d: 6} }
    let(:key_list) { [:a] }

    it { expect(Backend::File.query_from_list({})).to be_empty }
    it { expect(Backend::File.query_from_list(hash)).to eq("?a=1&b=2") }
    it { expect(Backend::File.query_from_list(hash_with_nil_values)).to eq("?a=1&b=2&c=&d=6") }
    it { expect(Backend::File.query_from_list(hash, key_list)).to eq("?a=1") }
  end
end
