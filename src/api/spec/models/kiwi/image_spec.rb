require 'rails_helper'
require 'webmock/rspec'

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
        expect(subject.description).to have_attributes(
          description_type: 'system',
          author: 'Christian Bruckmayer',
          contact: 'noemail@example.com',
          specification: 'Tiny, minimalistic appliances'
        )
      end

      it 'parses the preference type' do
        expect(subject.preference_type).to have_attributes(
          image_type: 'docker',
          containerconfig_name: 'my_container',
          containerconfig_tag: 'latest'
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

      it { expect(subject.valid?).to be_falsey }
      it { expect(subject.repositories).to be_empty }
      it { expect(subject.kiwi_packages).to be_empty }
    end

    context 'with multiple descriptions in the xml file' do
      subject { Kiwi::Image.build_from_xml(kiwi_xml_with_multiple_descriptions, 'some_md5') }

      it { expect(subject.valid?).to be_truthy }
      it { expect(subject.repositories).to be_empty }
      it { expect(subject.kiwi_packages).to be_empty }
      it 'parses only the description with type = "system"' do
        expect(subject.description).to have_attributes(
          description_type: 'system',
          author: 'Christian Bruckmayer',
          contact: 'noemail@example.com',
          specification: 'Tiny, minimalistic appliances'
        )
      end
    end
  end

  describe '#to_xml' do
    context 'without a package' do
      context 'with repositories, packages and preference_type' do
        before do
          kiwi_image.repositories << create(:kiwi_repository)
          kiwi_image.package_groups << create(:kiwi_package_group_non_empty, kiwi_type: 'image')
          kiwi_image.preference_type = create(:kiwi_preference_type)
          kiwi_image.save
        end

        subject { Nokogiri::XML::DocumentFragment.parse(kiwi_image.to_xml) }

        it { expect(subject.errors).to be_empty }
        it { expect(subject.xpath('.//image').length).to be(1) }
        it { expect(subject.xpath('.//image/description').length).to be(1) }
        it { expect(subject.xpath('.//image/packages').length).to be(1) }
        it { expect(subject.xpath('.//image/packages/package').length).to be(2) }
        it { expect(subject.xpath('.//image/repository').length).to be(1) }

        it 'output the xml for the preferences type' do
          expect(subject.xpath('.//image/preferences').length).to be(1)
          expect(subject.xpath('.//image/preferences/type[@image="docker"]/containerconfig').first).not_to be_nil
        end
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

      it 'returns the xml for the kiwi image correctly' do
        expect(subject.errors).to be_empty
        expect(subject.xpath('.//image').length).to be(1)
        expect(subject.xpath('.//image/description').length).to be(1)
        expect(subject.xpath(".//image/packages[@type='image']/package").length).to be(0)
        expect(subject.xpath('.//image/repository').length).to be(0)
      end
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

    context 'with a kiwi file with packages, repositories and a description' do
      let(:package) { create(:package) }
      let(:kiwi_image) { Kiwi::Image.build_from_xml(kiwi_xml, 'some_md5') }
      subject { Nokogiri::XML::DocumentFragment.parse(kiwi_image.to_xml) }

      before do
        allow(package).to receive(:kiwi_image_file).and_return('config.kiwi')
        allow(package).to receive(:source_file).and_return(kiwi_xml)
        kiwi_image.package = package
        kiwi_image.save
      end

      it { expect(subject.children[2].children[1].name).to eq('description') }
      it { expect(subject.children[2].children[1].children[1].name).to eq('author') }
      it { expect(subject.children[2].children[1].children[3].name).to eq('contact') }
      it { expect(subject.children[2].children[1].children[5].name).to eq('specification') }
      it { expect(subject.children[2].children[5].name).to eq('packages') }
      it { expect(subject.children[2].children[5].attributes['type'].value).to eq('image') }
      it { expect(subject.children[2].children[9].name).to eq('repository') }
      it { expect(subject.children[2].children[9].name).to eq('repository') }
      it { expect(subject.children[2].children[11].name).to eq('repository') }
      it { expect(subject.children[2].children[13].name).to eq('repository') }
    end

    context 'with a kiwi file without packages and repositories' do
      let(:package) { create(:package) }
      let(:kiwi_image) { Kiwi::Image.build_from_xml(Kiwi::Image::DEFAULT_KIWI_BODY, 'some_md5') }
      subject { Nokogiri::XML::DocumentFragment.parse(kiwi_image.to_xml) }

      before do
        allow(package).to receive(:kiwi_image_file).and_return('config.kiwi')
        allow(package).to receive(:source_file).and_return(Kiwi::Image::DEFAULT_KIWI_BODY)
        kiwi_image.save
        kiwi_image.package = package
        kiwi_image.package_groups << create(:kiwi_package_group_non_empty, kiwi_type: 'image')
        kiwi_image.repositories << create(:kiwi_repository)
        kiwi_image.save
      end

      it { expect(subject.children[2].children[5].name).to eq('packages') }
      it { expect(subject.children[2].children[7].name).to eq('repository') }
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

  describe '#binaries_available' do
    before do
      Rails.cache.clear
      path = "#{CONFIG['source_url']}/build/#{CGI.escape(project.name)}/_availablebinaries"
      stub_request(:get, path).and_return(body:
      "<availablebinaries>
          <packages>
            <arch>i586</arch>
            <name>package1</name>
            <name>package2</name>
          </packages>
          <packages>
            <arch>x86_64</arch>
            <name>package1</name>
            <name>package3</name>
          </packages>
        </availablebinaries>")
      stub_request(:get, "#{path}?path=#{CGI.escape(project.name)}/standard&url=#{CGI.escape('http://example.com/')}").and_return(body:
      "<availablebinaries>
          <packages>
            <arch>i586</arch>
            <name>package3</name>
            <name>package4</name>
          </packages>
          <packages>
            <arch>x86_64</arch>
            <name>package1</name>
            <name>package4</name>
          </packages>
        </availablebinaries>")
    end

    context 'with use_project_repositories set' do
      subject { Kiwi::Image.binaries_available(project.name, true, []) }

      it { expect(subject.keys).to match_array(['package1', 'package2', 'package3']) }
      it { expect(subject['package1']).to match_array(['i586', 'x86_64']) }
      it { expect(subject['package2']).to match_array(['i586']) }
      it { expect(subject['package3']).to match_array(['i586', 'x86_64']) }
    end

    context 'with OBS and "normal" repositories set' do
      subject { Kiwi::Image.binaries_available(project.name, false, ['obs://home:tom/standard', 'http://example.com/']) }

      it { expect(subject.keys).to match_array(['package1', 'package3', 'package4']) }
      it { expect(subject['package1']).to match_array(['x86_64']) }
      it { expect(subject['package3']).to match_array(['i586']) }
      it { expect(subject['package4']).to match_array(['i586', 'x86_64']) }
    end
  end

  describe '#find_binaries_by_name' do
    let(:binaries_available_sample) do
      { 'apache' => ['i586', 'x86_64'], 'apache2' => ['x86_64'],
        'appArmor' => ['i586', 'x86_64'], 'bcrypt' => ['x86_64'] }
    end

    before do
      allow(subject).to receive(:binaries_available).and_return(binaries_available_sample)
    end

    subject { Kiwi::Image }

    it { expect(subject.find_binaries_by_name('', 'project', [], use_project_repositories: true)).to eq(binaries_available_sample) }
    it do
      expect(subject.find_binaries_by_name('ap', 'project', [], use_project_repositories: true)).to eq({ 'apache' => ['i586', 'x86_64'],
        'apache2' => ['x86_64'], 'appArmor' => ['i586', 'x86_64'] })
    end
    it { expect(subject.find_binaries_by_name('app', 'project', [], use_project_repositories: true)).to eq({ 'appArmor' => ['i586', 'x86_64'] }) }
    it { expect(subject.find_binaries_by_name('b', 'project', [], use_project_repositories: true)).to eq({ 'bcrypt' => ['x86_64'] }) }
    it { expect(subject.find_binaries_by_name('c', 'project', [], use_project_repositories: true)).to be_empty }
  end

  describe '#parsed_errors' do
    let!(:kiwi_repository) { create(:kiwi_repository, image: kiwi_image) }
    let(:result) do
      {
        title: "title",
        "Image Errors:" =>
        [
          "Multiple package groups with same type are not allowed."
        ],
        "Repository: example" =>
        [
          "Source path can't be nil.",
          "Source path has an invalid format.",
          "is not a number",
          "Replaceable has to be a boolean"
        ]
      }
    end

    before do
      kiwi_image.repositories << Kiwi::Repository.new(alias: 'example')
      kiwi_image.package_groups << create(:kiwi_package_group_non_empty, kiwi_type: :image)
      kiwi_image.package_groups << create(:kiwi_package_group_non_empty, kiwi_type: :image)
      kiwi_image.valid?
    end

    subject { kiwi_image.parsed_errors('title', []) }

    it { expect(subject).to eq(result) }
  end
end
