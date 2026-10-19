RSpec.describe Vendor do
  describe '#logo=' do
    let(:vendor) { build(:vendor) }
    let(:file) do
      tempfile = Tempfile.new.tap do |t|
        t.binmode
        t.write("\x89PNG\r\n\x1a\ncontent".b)
        t.rewind
      end
      ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, type: 'image/png', filename: 'logo.png')
    end

    it 'sets the binary logo and extracts logo_content_type' do
      vendor.logo = file

      expect(vendor.logo).to eq("\x89PNG\r\n\x1a\ncontent".b)
      expect(vendor.logo_content_type).to eq('image/png')
    end
  end

  describe 'logo validation' do
    let(:vendor) { build(:vendor) }

    it 'accepts an image with matching MIME type and magic number' do
      vendor.logo_content_type = 'image/png'
      vendor.logo = "\x89PNG\r\n\x1a\nvalid_png".b

      expect(vendor).to be_valid
    end

    it 'rejects an image when magic bytes do not match the MIME type' do
      vendor.logo_content_type = 'image/png'
      vendor.logo = 'corrupted_or_fake_image_content'.b

      expect(vendor).not_to be_valid
      expect(vendor.errors[:logo]).to include('must be a valid image (JPEG, PNG, or WEBP)')
    end

    it 'rejects an image exceeding MAX_LOGO_SIZE' do
      vendor.logo_content_type = 'image/png'
      vendor.logo = "\x89PNG\r\n\x1a\n#{'0' * (Vendor::MAX_LOGO_SIZE + 1)}".b

      expect(vendor).not_to be_valid
      expect(vendor.errors[:logo]).to include('size cannot exceed 2 MB')
    end
  end

  describe '#logo_data_uri' do
    let(:vendor) { build(:vendor) }

    it 'returns nil when logo is blank' do
      vendor.logo = nil
      expect(vendor.logo_data_uri).to be_nil
    end

    it 'returns the Base64 data URI when logo is present' do
      vendor.logo_content_type = 'image/png'
      vendor.logo = "\x89PNG\r\n\x1a\n".b

      expected_base64 = Base64.strict_encode64("\x89PNG\r\n\x1a\n".b)
      expect(vendor.logo_data_uri).to eq("data:image/png;base64,#{expected_base64}")
    end
  end
end
