RSpec.describe Distro do
  describe 'name validation' do
    it { is_expected.to allow_value('openSUSE Leap 16').for(:name) }
    it { is_expected.not_to allow_value('Debian GNU/Linux').for(:name) }
    it { is_expected.to allow_value('Ubuntu 24.04').for(:name) }
    it { is_expected.to allow_value('foo_bar').for(:name) }
    it { is_expected.to allow_value('foo-bar').for(:name) }
  end

  describe 'logo validations' do
    let(:distro) { build(:distro) }

    context 'when no logo is attached' do
      it 'is valid' do
        expect(distro).to be_valid
      end
    end

    context 'when a logo is attached' do
      let(:file) { 'fake data' }
      let(:filename) { 'logo.png' }
      let(:content_type) { 'image/png' }

      before do
        distro.logo.attach(io: StringIO.new(file), filename: filename, content_type: content_type)
        distro.valid?
      end

      describe '#acceptable_logo_mime_type' do
        it 'is valid with a supported mime type' do
          expect(distro.errors[:logo]).not_to include('must be a PNG, JPEG, GIF or WebP image')
        end

        context 'when mime type is not supported' do
          let(:filename) { 'document.pdf' }
          let(:content_type) { 'application/pdf' }

          it 'is invalid' do
            expect(distro.errors[:logo]).to include('must be a PNG, JPEG, GIF or WebP image')
          end
        end
      end

      describe '#acceptable_logo_size' do
        context 'when the logo size is within the limit' do
          let(:file) { 'a' * 5.megabytes }

          it 'is valid' do
            expect(distro.errors[:logo]).not_to include('is too large (maximum is 5 MB)')
          end
        end

        context 'when the logo size exceeds 5 MB' do
          let(:file) { 'a' * (5.megabytes + 1) }

          it 'is invalid' do
            expect(distro.errors[:logo]).to include('is too large (maximum is 5 MB)')
          end
        end
      end
    end
  end
end
