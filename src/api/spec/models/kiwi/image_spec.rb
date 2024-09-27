require 'webmock/rspec'

RSpec.describe Kiwi::Image, :vcr do
  include_context 'a kiwi image xml'
  include_context 'an invalid kiwi image xml'

  let(:user) { create(:user, :with_home, login: 'tom') }
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

      it { is_expected.to be_valid }
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
        expect(subject.preferences.first).to have_attributes(
          version: '2.0.0',
          type_image: 'docker',
          type_containerconfig_name: 'my_container',
          type_containerconfig_tag: 'latest'
        )
      end

      it 'parses the selected profiles' do
        expect(subject.profiles.length).to eq(3)
        expect(subject.profiles[0]).to have_attributes(
          name: 'profile1',
          description: 'My first profile',
          selected: true
        )
        expect(subject.profiles[1]).to have_attributes(
          name: 'profile2',
          description: 'My second profile',
          selected: true
        )
        expect(subject.profiles[2]).to have_attributes(
          name: 'profile3',
          description: 'My third profile',
          selected: false
        )
      end
    end

    context 'with source_path' do
      context 'obsrepositories' do
        subject { Kiwi::Image.build_from_xml(kiwi_xml_with_obsrepositories, 'some_md5') }

        it { is_expected.to be_valid }
        it { is_expected.to be_use_project_repositories }

        it { expect(subject.repositories.length).to eq(0) }
      end

      context 'obsrepositories and others' do
        subject { Kiwi::Image.build_from_xml(invalid_kiwi_xml_with_obsrepositories, 'some_md5') }

        it { is_expected.not_to be_valid }
        it { is_expected.to be_use_project_repositories }

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

      it { is_expected.not_to be_valid }
    end

    context 'with a non xml Kiwi File it creates an empty image' do
      subject { Kiwi::Image.build_from_xml('', 'some_md5') }

      it { is_expected.not_to be_valid }
      it { expect(subject.repositories).to be_empty }
      it { expect(subject.kiwi_packages).to be_empty }
    end

    context 'with multiple descriptions in the xml file' do
      subject { Kiwi::Image.build_from_xml(kiwi_xml_with_multiple_descriptions, 'some_md5') }

      it { is_expected.to be_valid }
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
      context 'with repositories, packages and preference' do
        subject { Nokogiri::XML::Document.parse(kiwi_image.to_xml) }

        before do
          kiwi_image.repositories << create(:kiwi_repository)
          kiwi_image.package_groups << create(:kiwi_package_group_non_empty, kiwi_type: 'image')
          kiwi_image.save
        end

        it { expect(subject.errors).to be_empty }
        it { expect(subject.xpath('.//image').length).to be(1) }
        it { expect(subject.xpath('.//image/description').length).to be(1) }
        it { expect(subject.xpath('.//image/packages').length).to be(1) }
        it { expect(subject.xpath('.//image/packages/package').length).to be(2) }
        it { expect(subject.xpath('.//image/repository').length).to be(1) }

        it 'output the xml for the preferences type' do
          expect(subject.xpath('.//image/preferences').length).to be(1)
          expect(subject.xpath('.//image/preferences/type/containerconfig').first).not_to be_nil
          expect(subject.xpath('.//image/preferences/version').first).not_to be_nil
        end
      end

      context 'with preference type_image = "docker" but without containerconfig attributes' do
        subject { kiwi_image.to_xml }

        before do
          kiwi_image.preferences.first.update(type_containerconfig_name: nil, type_containerconfig_tag: nil)
        end

        it 'output the xml without any mention of containerconfig' do
          expect(subject).not_to include('<containerconfig')
        end
      end
    end

    context 'without kiwi image file' do
      subject { create(:kiwi_image_with_package, project: project) }

      after do
        login user
        subject.package.destroy
        logout
      end

      it 'returns nil' do
        expect(subject.to_xml).to be_nil
      end
    end

    context 'with kiwi image file' do
      subject { Nokogiri::XML::Document.parse(kiwi_image.to_xml) }

      let(:kiwi_image) { create(:kiwi_image_with_package, project: project, with_kiwi_file: true, file_content: kiwi_xml) }

      after do
        login user
        kiwi_image.package.destroy
        logout
      end

      it 'returns the xml for the kiwi image correctly' do
        expect(subject.errors).to be_empty
        expect(subject.xpath('.//image').length).to be(1)
        expect(subject.xpath('.//image/description').length).to be(1)
        expect(subject.xpath(".//image/packages[@type='image']/package").length).to be(0)
        expect(subject.xpath('.//image/repository').length).to be(0)
      end
    end

    context 'with a invalid kiwi image file' do
      subject { create(:kiwi_image_with_package, project: project, with_kiwi_file: true, file_content: 'Invalid content for a xml file') }

      after do
        login user
        subject.package.destroy
        logout
      end

      it { expect(subject.to_xml).to be_nil }
    end

    context 'with a invalid kiwi image file (without image children)' do
      subject do
        create(:kiwi_image_with_package, project: project,
                                         with_kiwi_file: true, file_content: 'Invalid content for a kiwi xml file<image></image>')
      end

      after do
        login user
        subject.package.destroy
        logout
      end

      it { expect(subject.to_xml).to be_nil }
    end

    context 'with a kiwi file with packages, repositories and a description' do
      subject { Nokogiri::XML::Document.parse(kiwi_image.to_xml) }

      let(:package) { create(:package) }
      let(:kiwi_image) { Kiwi::Image.build_from_xml(kiwi_xml, 'some_md5') }

      before do
        allow(package).to receive_messages(kiwi_image_file: 'config.kiwi', source_file: kiwi_xml)
        kiwi_image.package = package
        kiwi_image.save
      end

      it { expect(subject.xpath('image/description/author').present?).to be true }
      it { expect(subject.xpath('image/description/contact').present?).to be true }
      it { expect(subject.xpath('image/description/specification').present?).to be true }
      it { expect(subject.xpath('image/packages').attribute('type').value).to eq('image') }
      it { expect(subject.xpath('image/repository').count).to eq(4) }
    end

    context 'with a kiwi file without packages and repositories' do
      subject { Nokogiri::XML::Document.parse(kiwi_image.to_xml) }

      let(:package) { create(:package) }
      let(:kiwi_image) { Kiwi::Image.build_from_xml(Kiwi::Image::DEFAULT_KIWI_BODY, 'some_md5') }

      before do
        allow(package).to receive_messages(kiwi_image_file: 'config.kiwi', source_file: Kiwi::Image::DEFAULT_KIWI_BODY)
        kiwi_image.save
        kiwi_image.package = package
        kiwi_image.package_groups << create(:kiwi_package_group_non_empty, kiwi_type: 'image')
        kiwi_image.repositories << create(:kiwi_repository)
        kiwi_image.save
      end

      it { expect(subject.children[0].children[5].name).to eq('packages') }
      it { expect(subject.children[0].children[7].name).to eq('repository') }
    end
  end

  describe '.write_to_backend' do
    context 'without a package' do
      it { expect(kiwi_image.write_to_backend).to be(false) }

      it 'does not call save! method' do
        allow(kiwi_image).to receive(:save!)
        kiwi_image.write_to_backend
        expect(kiwi_image).not_to have_received(:save!)
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

      it { expect(subject.keys).to contain_exactly('package1', 'package2', 'package3') }
      it { expect(subject['package1']).to contain_exactly('i586', 'x86_64') }
      it { expect(subject['package2']).to contain_exactly('i586') }
      it { expect(subject['package3']).to contain_exactly('x86_64') }
    end

    context 'with OBS and "normal" repositories set' do
      subject { Kiwi::Image.binaries_available(project.name, false, ['obs://home:tom/standard', 'http://example.com/']) }

      it { expect(subject.keys).to contain_exactly('package1', 'package3', 'package4') }
      it { expect(subject['package1']).to contain_exactly('x86_64') }
      it { expect(subject['package3']).to contain_exactly('i586') }
      it { expect(subject['package4']).to contain_exactly('i586', 'x86_64') }
    end
  end

  describe '#find_binaries_by_name' do
    subject { Kiwi::Image }

    let(:binaries_available_sample) do
      { 'apache' => %w[i586 x86_64], 'apache2' => ['x86_64'],
        'appArmor' => %w[i586 x86_64], 'bcrypt' => ['x86_64'] }
    end

    before do
      allow(Kiwi::Image).to receive(:binaries_available).and_return(binaries_available_sample)
    end

    it { expect(subject.find_binaries_by_name('', 'project', [], use_project_repositories: true)).to eq(binaries_available_sample) }

    it do
      expect(subject.find_binaries_by_name('ap', 'project', [], use_project_repositories: true)).to eq('apache' => %w[i586 x86_64],
                                                                                                       'apache2' => ['x86_64'], 'appArmor' => %w[i586 x86_64])
    end

    it { expect(subject.find_binaries_by_name('app', 'project', [], use_project_repositories: true)).to eq('appArmor' => %w[i586 x86_64]) }
    it { expect(subject.find_binaries_by_name('b', 'project', [], use_project_repositories: true)).to eq('bcrypt' => ['x86_64']) }
    it { expect(subject.find_binaries_by_name('c', 'project', [], use_project_repositories: true)).to be_empty }
  end

  describe '#nested_error_messages' do
    subject { kiwi_image.nested_error_messages }

    let!(:kiwi_repository) { create(:kiwi_repository, image: kiwi_image) }
    let(:result) do
      {
        'Repository: http://example.com/' => [
          "Source path can't be nil",
          'Source path has an invalid format',
          'Order is not a number',
          'Replaceable has to be a boolean'
        ],
        'Package: ' => [
          "Name can't be blank"
        ],
        'Image Errors:' => [
          "Name can't be blank"
        ]
      }
    end

    before do
      kiwi_image.name = nil
      kiwi_image.repositories << Kiwi::Repository.new(alias: 'example')
      kiwi_image.package_groups << create(:kiwi_package_group_non_empty, kiwi_type: :image)
      kiwi_image.package_groups[0].packages[0].name = nil
      kiwi_image.valid?
    end

    it { is_expected.to eq(result) }
  end
end
