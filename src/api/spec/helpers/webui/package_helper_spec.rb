require 'rails_helper'
require 'rantly/rspec_extensions'

RSpec.describe Webui::PackageHelper, type: :helper do
  describe '#nbsp' do
    it 'produces a SafeBuffer' do
      sanitized_string = nbsp("a")
      expect(sanitized_string).to be_a(ActiveSupport::SafeBuffer)
    end

    it 'escapes html' do
      sanitized_string = nbsp('<b>unsafe<b/>')
      expect(sanitized_string).to eq('&lt;b&gt;unsafe&lt;b/&gt;')
    end

    it 'converts space to nbsp' do
      sanitized_string = nbsp("my file")
      expect(sanitized_string).to eq('my&nbsp;file')
    end

    it 'breaks up long strings' do
      long_string = "a" * 50 + "b" * 50 + "c" * 10
      sanitized_string = nbsp(long_string)
      expect(long_string.scan(/.{1,50}/).join("<wbr>")).to eq(sanitized_string)
    end
  end

  describe '#title_or_name' do
    it 'returns package name when title is empty' do
      package = create(:package, name: 'openSUSE', title: '')
      expect(title_or_name(package)).to eq('openSUSE')
    end

    it 'returns package name when title is nil' do
      package = create(:package, name: 'openSUSE', title: nil)
      expect(title_or_name(package)).to eq('openSUSE')
    end

    it 'returns package title when title is set' do
      package = create(:package, name: 'openSUSE', title: 'Leap')
      expect(title_or_name(package)).to eq('Leap')
    end
  end

  describe '#humanize_time' do
    it 'returns seconds' do
      expect(humanize_time(28)).to eq('28s')
    end

    it 'returns minutes and seconds' do
      expect(humanize_time(88)).to eq('1m 28s')
    end

    it 'returns hours, minutes and seconds' do
      expect(humanize_time(3688)).to eq('1h 1m 28s')
    end
  end

  describe '#file_url' do
    skip
  end

  describe '#rpm_url' do
    skip
  end

  describe '#human_readable_fsize' do
    skip
  end

  describe '#guess_code_class' do
    RSpec.shared_examples "file with extension" do |extension, extension_class|
      it "returns correct extension" do
        property_of {
          sized(1) { string(/[\w+\-:]/) } + sized(range(0, 190)) { string(/[\w+\-:\.]/) } + '.' + extension
        }.check(3) { |filename|
          expect(guess_code_class(filename)).to eq(extension_class)
        }
      end
    end
    context "is xml" do
      it { expect(guess_code_class('_aggregate')).to eq('xml') }
      it { expect(guess_code_class('_link')).to eq('xml') }
      it { expect(guess_code_class('_patchinfo')).to eq('xml') }
      it { expect(guess_code_class('_service')).to eq('xml') }

      it "when it ends by .service" do
        property_of {
          sized(range(1, 191)) { string(/./) } + '.service'
        }.check(3) { |filename|
          expect(guess_code_class(filename)).to eq('xml')
        }
      end

      it_should_behave_like "file with extension", 'group', 'xml'
      it_should_behave_like "file with extension", 'kiwi', 'xml'
      it_should_behave_like "file with extension", 'product', 'xml'
      it_should_behave_like "file with extension", 'xml', 'xml'
    end

    context "is shell" do
      it "with rc-scripts" do
        property_of {
          'rc' + sized(range(1, 197)) { string(/[\w-]/) }
        }.check(3) { |filename|
          expect(guess_code_class(filename)).to eq('shell')
        }
      end
    end

    context "is python" do
      it "when it ends in rpmlintrc" do
        property_of {
          sized(range(0, 190)) { string(/./) } + 'rpmlintrc'
        }.check(3) { |filename|
          expect(guess_code_class(filename)).to eq('python')
        }
      end
    end

    context "is makefile" do
      it { expect(guess_code_class("debian.rules")).to eq 'makefile' }
    end

    context "is baselibs" do
      it { expect(guess_code_class("baselibs.conf")).to eq 'baselibs' }
    end

    context "is spec" do
      it "when it starts with macros." do
        property_of {
          'macros.' + sized(range(1, 192)) { string(/\w/) }
        }.check(3) { |filename|
          expect(guess_code_class(filename)).to eq('spec')
        }
      end
    end

    context "is diff" do
      it_should_behave_like "file with extension", 'patch', 'diff'
      it_should_behave_like "file with extension", 'dif', 'diff'
      it_should_behave_like "file with extension", 'diff', 'diff'
    end

    context "is perl" do
      it_should_behave_like "file with extension", 'pl', 'perl'
      it_should_behave_like "file with extension", 'pm', 'perl'
      it_should_behave_like "file with extension", 'perl', 'perl'
    end

    context "is python" do
      it_should_behave_like "file with extension", 'py', 'python'
    end

    context "is ruby" do
      it_should_behave_like "file with extension", 'rb', 'ruby'
    end

    context "is latex" do
      it_should_behave_like "file with extension", 'tex', 'latex'
    end

    context "is javascript" do
      it_should_behave_like "file with extension", 'js', 'javascript'
    end

    context "is shell" do
      it_should_behave_like "file with extension", 'sh', 'shell'
    end

    context "is rpm-spec" do
      it_should_behave_like "file with extension", 'spec', 'rpm-spec'
    end

    context "is rpm-changes" do
      it_should_behave_like "file with extension", 'changes', 'rpm-changes'
    end

    context "is php" do
      it_should_behave_like "file with extension", 'php', 'php'
    end

    context "is html" do
      it_should_behave_like "file with extension", 'html', 'html'
    end

    context "is dockerfile" do
      it "when it starts with Dockerfile." do
        property_of {
          'Dockerfile.' + sized(range(1, 192)) { string(/\w/) }
        }.check(3) { |filename|
          expect(guess_code_class(filename)).to eq('dockerfile')
        }
      end

      it { expect(guess_code_class('Dockerfile')).to eq('dockerfile') }
      it { expect(guess_code_class('dockerfile')).to eq('dockerfile') }
    end

    context "css" do
      it_should_behave_like "file with extension", 'css', 'css'
    end

    context "other" do
      it { expect(guess_code_class("other")).to eq '' }
    end
  end

  describe '#package_bread_crumb' do
    skip
  end

  describe '#binaries?' do
    context 'with a buildresult with one result' do
      let(:subject) {
        {
          result: {
            binarylist: {
              binary: [
                { filename: '_buildenv', size: '13722', mtime: '1493898933' }
              ]
            }
          }
        }.with_indifferent_access
      }

      it 'returns true' do
        expect(binaries?(subject)).to eq(true)
      end
    end

    context 'with a buildresult with more than one result' do
      let(:subject) {
        {
          result: [
            {
              binarylist: {
                binary: [
                  { filename: '_buildenv', size: '13722', mtime: '1493898933' }
                ]
              }
            },
            {
              binarylist: {
                binary: [
                  { filename: '_buildenv', size: '13722', mtime: '1493898933' }
                ]
              }
            }
          ]
        }.with_indifferent_access
      }

      it 'returns true' do
        expect(binaries?(subject)).to eq(true)
      end
    end

    context 'with a buildresult without any result' do
      let(:subject) { ActiveSupport::HashWithIndifferentAccess.new }

      it 'returns false' do
        expect(binaries?(subject)).to eq(false)
      end
    end

    context 'with a buildresult without a binarylist' do
      let(:subject) { { result: ActiveSupport::HashWithIndifferentAccess.new } }

      it 'returns false' do
        expect(binaries?(subject)).to eq(false)
      end
    end
  end
end
