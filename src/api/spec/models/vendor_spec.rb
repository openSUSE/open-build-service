RSpec.describe Vendor do
  describe 'logo validations' do
    let(:vendor) { build(:vendor) }

    context 'when no logo is attached' do
      it 'is valid' do
        expect(vendor).to be_valid
      end
    end

    context 'when a logo is attached' do
      let(:file) { 'fake data' }
      let(:filename) { 'logo.png' }
      let(:content_type) { 'image/png' }

      before do
        vendor.logo.attach(io: StringIO.new(file), filename: filename, content_type: content_type)
        vendor.valid?
      end

      describe '#acceptable_logo_mime_type' do
        it 'is valid with a supported mime type' do
          expect(vendor.errors[:logo]).not_to include('must be a PNG, JPEG, GIF or WebP image')
        end

        context 'when mime type is not supported' do
          let(:filename) { 'document.pdf' }
          let(:content_type) { 'application/pdf' }

          it 'is invalid' do
            expect(vendor.errors[:logo]).to include('must be a PNG, JPEG, GIF or WebP image')
          end
        end
      end

      describe '#acceptable_logo_size' do
        context 'when the logo size is within the limit' do
          let(:file) { 'a' * 5.megabytes }

          it 'is valid' do
            expect(vendor.errors[:logo]).not_to include('is too large (maximum is 5 MB)')
          end
        end

        context 'when the logo size exceeds 5 MB' do
          let(:file) { 'a' * (5.megabytes + 1) }

          it 'is invalid' do
            expect(vendor.errors[:logo]).to include('is too large (maximum is 5 MB)')
          end
        end
      end
    end
  end
end
