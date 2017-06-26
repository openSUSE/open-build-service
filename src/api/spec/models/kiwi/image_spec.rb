require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Kiwi::Image, type: :model, vcr: true do
  include_context 'a kiwi image xml'
  include_context 'an invalid kiwi image xml'

  let(:kiwi_image) { create(:kiwi_image) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to have_one(:package) }
    it { is_expected.to have_many(:repositories) }
    it { is_expected.to accept_nested_attributes_for(:repositories) }

    context 'with an outdated image' do
      let(:kiwi_image_with_package) { create(:kiwi_image_with_package) }
      before do
        allow_any_instance_of(Package).to receive(:kiwi_image_outdated?) { true }
      end

      it {
        expect{ kiwi_image_with_package.update_attributes!(name: 'Other name') }.to raise_error(
          ActiveRecord::RecordInvalid, 'Validation failed: Image configuration has changed')
      }
    end
  end

  describe '.build_from_xml' do
    context 'with a valid Kiwi File' do
      subject { Kiwi::Image.build_from_xml(kiwi_xml, 'some_md5') }

      it { expect(subject.valid?).to be_truthy }
      it { expect(subject.name).to eq('Christians_openSUSE_13.2_JeOS') }

      it 'parses the repository elements of the xml into a KiwiImage model' do
        expect(subject.repositories[0]).to have_attributes(
          source_path: 'http://download.opensuse.org/update/13.2/',
          repo_type: 'apt-deb',
          priority: 10,
          order: 1,
          alias: 'debian',
          imageinclude: true,
          password: '123456',
          prefer_license: true,
          replaceable: true,
          username: 'Tom'
        )
        expect(subject.repositories[1]).to have_attributes(
          source_path: 'http://download.opensuse.org/distribution/13.2/repo/oss/',
          repo_type: 'rpm-dir',
          priority: 20,
          order: 2,
          alias: nil,
          imageinclude: false,
          password: nil,
          prefer_license: false,
          replaceable: false,
          username: nil
        )
        expect(subject.repositories[2]).to have_attributes(
          source_path: 'http://download.opensuse.org/distribution/13.1/repo/oss/',
          repo_type: 'rpm-md',
          priority: 20,
          order: 3,
          alias: nil,
          imageinclude: nil,
          password: nil,
          prefer_license: nil,
          replaceable: false,
          username: nil
        )
        expect(subject.repositories[3]).to have_attributes(
          source_path: 'http://download.opensuse.org/distribution/12.1/repo/oss/',
          repo_type: 'rpm-md',
          priority: nil,
          order: 4,
          alias: nil,
          imageinclude: nil,
          password: nil,
          prefer_license: nil,
          replaceable: false,
          username: nil
        )
      end
    end

    context 'with an invalid Kiwi File' do
      subject { Kiwi::Image.build_from_xml(invalid_kiwi_xml, 'some_md5') }

      it { expect(subject.valid?).to be_falsey }
    end
  end

  describe '.to_xml' do
    context 'without kiwi image file' do
      it 'returns nil' do
        dbl_package = double("Some Package")
        allow(dbl_package).to receive(:kiwi_image_file)
        allow(kiwi_image).to receive(:package).and_return(dbl_package)

        expect(kiwi_image.to_xml).to be_nil
      end
    end

    context 'with kiwi image file' do
      before do
        dbl_package = double('Some Package')
        allow(dbl_package).to receive(:kiwi_image_file).and_return('fake_filename.kiwi')
        allow(dbl_package).to receive_messages(source_file: kiwi_xml)
        allow(kiwi_image).to receive(:package).and_return(dbl_package)
      end

      subject { Nokogiri::XML::DocumentFragment.parse(kiwi_image.to_xml) }

      it { expect(subject.errors).to be_empty }
      it { expect(subject.xpath('.//image').length).to be(1) }
      it { expect(subject.xpath('.//image/description').length).to be(1) }
      it { expect(subject.xpath('.//image/packages/package').length).to be(20) }
      it { expect(subject.xpath('.//image/repository').length).to be(0) }
    end
  end
end
