require 'rantly/rspec_extensions'

RSpec.describe Webui::PackageHelper do
  describe '#removable_file?' do
    let(:package) { create(:package, name: 'bar') }

    it { expect(removable_file?(file_name: 'foo',               package: package)).to be true }
    it { expect(removable_file?(file_name: '_service',          package: package)).to be true }
    it { expect(removable_file?(file_name: '_service:sub_file', package: package)).to be false }

    context 'a product package (_product)' do
      let(:package) { create(:package, name: '_product') }

      it 'can be removed' do
        expect(removable_file?(file_name: 'foo', package: package)).to be true
      end
    end

    context 'a product sub package (_product:*)' do
      let(:project) { create(:project) }
      let(:product_sub_package) { create(:package, name: '_product:foo', project: project) }

      context 'that belongs to a _product file' do
        before do
          allow(product_sub_package).to receive(:belongs_to_product?).and_return(true)
        end

        it { expect(removable_file?(file_name: 'foo', package: product_sub_package)).to be false }
      end

      context 'that does not belong to a _product file' do
        before do
          allow(product_sub_package).to receive(:belongs_to_product?).and_return(false)
        end

        it { expect(removable_file?(file_name: 'foo', package: product_sub_package)).to be true }
      end
    end
  end

  describe '#nbsp' do
    it 'produces a SafeBuffer' do
      sanitized_string = nbsp('a')
      expect(sanitized_string).to be_a(ActiveSupport::SafeBuffer)
    end

    it 'escapes html' do
      sanitized_string = nbsp('<b>unsafe<b/>')
      expect(sanitized_string).to eq('&lt;b&gt;unsafe&lt;b/&gt;')
    end

    it 'converts space to nbsp' do
      sanitized_string = nbsp('my file')
      expect(sanitized_string).to eq('my&nbsp;file')
    end

    it 'breaks up long strings' do
      long_string = ('a' * 50) + ('b' * 50) + ('c' * 10)
      sanitized_string = nbsp(long_string)
      expect(long_string.scan(/.{1,50}/).join('<wbr>')).to eq(sanitized_string)
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

    it 'returns days, hours, minutes and seconds' do
      expect(humanize_time(53 * 4283)).to eq('2d 15h 3m 19s')
    end
  end

  describe '#file_url'

  describe '#rpm_url'

  describe '#human_readable_fsize'

  describe '#guess_code_class' do
    RSpec.shared_examples 'file with extension' do |extension, extension_class|
      it 'returns correct extension' do
        property_of do
          "#{sized(1) { string(/[\w+\-:]/) }}#{sized(range(0, 190)) { string(/[\w+\-:.]/) }}.#{extension}"
        end.check(3) do |filename|
          expect(guess_code_class(filename)).to eq(extension_class)
        end
      end
    end

    context 'is xml' do
      it { expect(guess_code_class('_aggregate')).to eq('xml') }
      it { expect(guess_code_class('_link')).to eq('xml') }
      it { expect(guess_code_class('_patchinfo')).to eq('xml') }
      it { expect(guess_code_class('_service')).to eq('xml') }

      it 'when it ends by .service' do
        property_of do
          "#{sized(range(1, 191)) { string(/./) }}.service"
        end.check(3) do |filename|
          expect(guess_code_class(filename)).to eq('xml')
        end
      end

      it_behaves_like 'file with extension', 'group', 'xml'
      it_behaves_like 'file with extension', 'kiwi', 'xml'
      it_behaves_like 'file with extension', 'product', 'xml'
      it_behaves_like 'file with extension', 'xml', 'xml'
    end

    context 'is shell' do
      it 'with rc-scripts' do
        property_of do
          "rc#{sized(range(1, 197)) { string(/[\w-]/) }}"
        end.check(3) do |filename|
          expect(guess_code_class(filename)).to eq('shell')
        end
      end

      it_behaves_like 'file with extension', 'sh', 'shell'
    end

    context 'is python' do
      it 'when it ends in rpmlintrc' do
        property_of do
          "#{sized(range(0, 190)) { string(/./) }}rpmlintrc"
        end.check(3) do |filename|
          expect(guess_code_class(filename)).to eq('python')
        end
      end

      it_behaves_like 'file with extension', 'py', 'python'
    end

    context 'is makefile' do
      it { expect(guess_code_class('debian.rules')).to eq('makefile') }
    end

    context 'is baselibs' do
      it { expect(guess_code_class('baselibs.conf')).to eq('baselibs') }
    end

    context 'is spec' do
      it 'when it starts with macros.' do
        property_of do
          "macros.#{sized(range(1, 192)) { string(/\w/) }}"
        end.check(3) do |filename|
          expect(guess_code_class(filename)).to eq('spec')
        end
      end
    end

    context 'is diff' do
      it_behaves_like 'file with extension', 'patch', 'diff'
      it_behaves_like 'file with extension', 'dif', 'diff'
      it_behaves_like 'file with extension', 'diff', 'diff'
    end

    context 'is perl' do
      it_behaves_like 'file with extension', 'pl', 'perl'
      it_behaves_like 'file with extension', 'pm', 'perl'
      it_behaves_like 'file with extension', 'perl', 'perl'
    end

    context 'is ruby' do
      it_behaves_like 'file with extension', 'rb', 'ruby'
    end

    context 'is latex' do
      it_behaves_like 'file with extension', 'tex', 'latex'
    end

    context 'is javascript' do
      it_behaves_like 'file with extension', 'js', 'javascript'
    end

    context 'is rpm-spec' do
      it_behaves_like 'file with extension', 'spec', 'rpm-spec'
    end

    context 'is rpm-changes' do
      it_behaves_like 'file with extension', 'changes', 'rpm-changes'
    end

    context 'is php' do
      it_behaves_like 'file with extension', 'php', 'php'
    end

    context 'is html' do
      it_behaves_like 'file with extension', 'html', 'html'
    end

    context 'is dockerfile' do
      it 'when it starts with Dockerfile.' do
        property_of do
          "Dockerfile.#{sized(range(1, 192)) { string(/\w/) }}"
        end.check(3) do |filename|
          expect(guess_code_class(filename)).to eq('dockerfile')
        end
      end

      it { expect(guess_code_class('Dockerfile')).to eq('dockerfile') }
      it { expect(guess_code_class('dockerfile')).to eq('dockerfile') }
    end

    context 'css' do
      it_behaves_like 'file with extension', 'css', 'css'
    end

    context 'other' do
      it { expect(guess_code_class('other')).to eq('') }
    end
  end

  describe '#expand_diff?' do
    it { expect(expand_diff?('ctris.spec', 'added')).to be true }
    it { expect(expand_diff?('_patchinfo', 'added')).to be true }
    it { expect(expand_diff?('ctris.changes', 'added')).to be true }
    it { expect(expand_diff?('ctris.changes', 'deleted')).to be false }
    it { expect(expand_diff?('/foo/bar/test.txt', 'added')).to be false }
  end

  describe '#calculate_revision_on_state' do
    it { expect(calculate_revision_on_state('1', 'deleted')).to eq(0) }
    it { expect(calculate_revision_on_state('0', 'deleted')).to eq(0) }
    it { expect(calculate_revision_on_state('1', 'added')).to eq(1) }
  end

  describe '#viewable_file?' do
    it { expect(viewable_file?('some/file')).to be(false) }
    it { expect(viewable_file?('some_file.rb')).to be(true) }
    it { expect(viewable_file?('some_file.bin')).to be(false) }
  end

  describe '#binary_file?' do
    it { expect(binary_file?('anNhbG.exe')).to be(true) }
    it { expect(binary_file?('ZramE7b2.bin')).to be(true) }
    it { expect(binary_file?('g3cWhqem.tar')).to be(true) }
    it { expect(binary_file?('x3ZXVqaDg.tar.bz')).to be(true) }
    it { expect(binary_file?('zNDd1NDU5O.tar.bz2')).to be(true) }
    it { expect(binary_file?('Dd5MnE0Ly.tar.zst')).to be(true) }
    it { expect(binary_file?('4vLi8uNTMvN.gem')).to be(true) }
    it { expect(binary_file?('S40LjUzOV.gif')).to be(true) }
    it { expect(binary_file?('BISTs7U.jpg')).to be(true) }
    it { expect(binary_file?('RGVUpF.jpeg')).to be(true) }
    it { expect(binary_file?('U0hLSl.ttf')).to be(true) }
    it { expect(binary_file?('ERgo.zip')).to be(true) }
    it { expect(binary_file?('NDg3Mj/UyMDg3U.tar.gz')).to be(true) }
    it { expect(binary_file?('kZJVUhWSk.png')).to be(true) }
    it { expect(binary_file?('tIRkdJREta.gem')).to be(true) }
    it { expect(binary_file?('WFk5V1dXV.cert')).to be(true) }
    it { expect(binary_file?('MzQ1OHI3OGZ5ZW.svgz')).to be(true) }
    it { expect(binary_file?('hzeml5OTc2e.taz')).to be(true) }
    it { expect(binary_file?('WZ6OTdneXJqa.tlz')).to be(true) }
    it { expect(binary_file?('3c0ZWdha.diff')).to be(false) }
    it { expect(binary_file?('GpyNWpoc.txt')).to be(false) }
    it { expect(binary_file?('0ZLREpoCg.csv')).to be(false) }
    it { expect(binary_file?('YWprd2Fqb.pm')).to be(false) }
    it { expect(binary_file?('GtqbWttLG.c')).to be(false) }
    it { expect(binary_file?('ZuYW5tIGJ0.rb')).to be(false) }
    it { expect(binary_file?('NGkzNzV5.h')).to be(false) }
    it { expect(binary_file?('Jmc2hiCg.spec')).to be(false) }
  end
end
