require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Kiwi::Image, type: :model, vcr: true do
  include_context 'a kiwi image xml'
  include_context 'an invalid kiwi image xml'

  let(:user) { create(:user, login: 'tom') }
  let(:project) { user.home_project }
  let(:kiwi_image) { create(:kiwi_image) }

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
        subject.valid?
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
          repo_type: 'rpm-md',
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
        expect(subject.package_groups.first).to have_attributes(
          kiwi_type: 'image',
          pattern_type: 'onlyRequired',
          profiles: nil
        )
        expect(subject.package_groups.first.packages.first).to have_attributes(
          name: 'e2fsprogs',
          arch: nil,
          replaces: nil,
          bootinclude: nil,
          bootdelete: nil
        )
        expect(subject.package_groups.first.packages.last).to have_attributes(
          name: 'gfxboot-devel',
          arch: nil,
          replaces: nil,
          bootinclude: true,
          bootdelete: nil
        )
        expect(subject.package_groups.last).to have_attributes(
          kiwi_type: 'delete',
          pattern_type: nil,
          profiles: nil
        )
        expect(subject.package_groups.last.packages.first).to have_attributes(
          name: 'e2fsprogss',
          arch: nil,
          replaces: nil,
          bootinclude: nil,
          bootdelete: nil
        )
      end
    end

    context 'with source_path' do
      context 'obsrepositories' do
        subject { Kiwi::Image.build_from_xml(kiwi_xml_with_obsrepositories, 'some_md5') }

        it { expect(subject.valid?).to be_truthy }
        it { expect(subject.use_project_repositories?).to be_truthy }

        it { expect(subject.repositories.length).to eq(0) }
      end

      context 'obsrepositories and others' do
        subject { Kiwi::Image.build_from_xml(invalid_kiwi_xml_with_obsrepositories, 'some_md5') }

        it { expect(subject.valid?).to be_falsey }
        it { expect(subject.use_project_repositories?).to be_truthy }

        it { expect(subject.repositories.length).to eq(1) }
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
        end
      end
    end

    context 'with an invalid Kiwi File' do
      subject { Kiwi::Image.build_from_xml(invalid_kiwi_xml, 'some_md5') }

      it { expect(subject.valid?).to be_falsey }
    end

    context 'with a non xml Kiwi File it creates an empty image' do
      subject { Kiwi::Image.build_from_xml('', 'some_md5') }

      it { expect(subject.valid?).to be_truthy }
      it { expect(subject.repositories).to be_empty }
      it { expect(subject.kiwi_packages).to be_empty }
    end
  end

  describe '#to_xml' do
    context 'without a package' do
      context 'without any repository or package' do
        it { expect(kiwi_image.to_xml).to eq(Kiwi::Image::DEFAULT_KIWI_BODY) }
      end

      context 'with some repositories and packages' do
        before do
          kiwi_image.repositories << create(:kiwi_repository)
          kiwi_image.package_groups << create(:kiwi_package_group_non_empty)
        end

        subject { Nokogiri::XML::DocumentFragment.parse(kiwi_image.to_xml) }

        it { expect(subject.errors).to be_empty }
        it { expect(subject.xpath('.//image').length).to be(1) }
        it { expect(subject.xpath('.//image/description').length).to be(1) }
        it { expect(subject.xpath('.//image/packages').length).to be(1) }
        it { expect(subject.xpath('.//image/packages/package').length).to be(2) }
        it { expect(subject.xpath('.//image/repository').length).to be(1) }
      end
    end

    context 'without kiwi image file' do
      after do
        login user
        subject.package.destroy
        logout
      end

      subject { create(:kiwi_image_with_package, project: project) }

      it 'returns nil' do
        expect(subject.to_xml).to be_nil
      end
    end

    context 'with kiwi image file' do
      let(:kiwi_image) { create(:kiwi_image_with_package, project: project, with_kiwi_file: true, file_content: kiwi_xml) }

      after do
        login user
        kiwi_image.package.destroy
        logout
      end

      subject { Nokogiri::XML::DocumentFragment.parse(kiwi_image.to_xml) }

      it { expect(subject.errors).to be_empty }
      it { expect(subject.xpath('.//image').length).to be(1) }
      it { expect(subject.xpath('.//image/description').length).to be(1) }
      it { expect(subject.xpath('.//image/packages/package').length).to be(0) }
      it { expect(subject.xpath('.//image/repository').length).to be(0) }
    end

    context 'with a invalid kiwi image file' do
      after do
        login user
        subject.package.destroy
        logout
      end

      subject { create(:kiwi_image_with_package, project: project, with_kiwi_file: true, file_content: 'Invalid content for a xml file') }

      it { expect(subject.to_xml).to be_nil }
    end

    context 'with a invalid kiwi image file (without image children)' do
      after do
        login user
        subject.package.destroy
        logout
      end

      subject do
        create(:kiwi_image_with_package, project: project,
               with_kiwi_file: true, file_content: 'Invalid content for a kiwi xml file<image></image>')
      end

      it { expect(subject.to_xml).to be_nil }
    end
  end

  describe '.write_to_backend' do
    context 'without a package' do
      it { expect(kiwi_image.write_to_backend).to be(false) }
      it 'will not call save! method' do
        expect(kiwi_image).not_to receive(:save!)
        kiwi_image.write_to_backend
      end
    end

    context 'with a package' do
      before do
        login user

        subject.write_to_backend
      end

      after do
        subject.package.destroy
        logout
      end

      context 'without a kiwi file' do
        subject { create(:kiwi_image_with_package, project: project) }

        it { expect(subject.outdated?).to be(false) }
        it { expect(subject.package.kiwi_image_file).to eq("#{subject.package.name}.kiwi") }
      end

      context 'with a kiwi file' do
        subject { create(:kiwi_image_with_package, project: project, with_kiwi_file: true, kiwi_file_name: 'other_file_name.kiwi') }

        it { expect(subject.outdated?).to be(false) }
        it { expect(subject.package.kiwi_image_file).to eq('other_file_name.kiwi') }
      end
    end
  end

  describe '.outdated?' do
    context 'without a package' do
      it { expect(kiwi_image.outdated?).to be(false) }
    end

    context 'with a package' do
      context 'without a kiwi file' do
        let(:kiwi_image_with_package) { create(:kiwi_image_with_package, project: project, package_name: 'package_without_kiwi_file') }

        it { expect(kiwi_image_with_package.outdated?).to be(true) }
      end

      context 'with a kiwi file' do
        let(:kiwi_image_with_package_with_kiwi_file) do
          create(:kiwi_image_with_package, project: project, package_name: 'package_with_kiwi_file', with_kiwi_file: true)
        end

        context 'different md5' do
          before do
            kiwi_image_with_package_with_kiwi_file.md5_last_revision = 'FAKE md5'
            kiwi_image_with_package_with_kiwi_file.save
          end

          it { expect(kiwi_image_with_package_with_kiwi_file.outdated?).to be(true) }
        end

        context 'same md5' do
          it { expect(kiwi_image_with_package_with_kiwi_file.outdated?).to be(false) }
        end
      end
    end
  end
end
