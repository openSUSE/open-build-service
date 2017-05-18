require 'rails_helper'

RSpec.describe Kiwi::Image, type: :model do
  include_context 'a kiwi image xml'
  include_context 'an invalid kiwi image xml'

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to have_one(:package) }
    it { is_expected.to have_many(:repositories) }
    it { is_expected.to accept_nested_attributes_for(:repositories) }
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
end
