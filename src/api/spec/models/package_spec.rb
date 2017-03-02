require 'rails_helper'
require 'webmock/rspec'
require 'rantly/rspec_extensions'
# WARNING: If you change #file_exists or #has_file test make sure
# you uncomment the next line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Package, vcr: true do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:home_project) { user.home_project }
  let(:package) { create(:package, name: 'test_package', project: home_project) }
  let(:package_with_file) { create(:package_with_file, name: 'package_with_files', project: home_project) }
  let(:package_with_broken_service) { create(:package_with_broken_service, name: "package_with_broken_service", project: user.home_project) }
  let(:package_with_service) { create(:package_with_service, name: "package_with_service", project: user.home_project) }
  let(:services) { package.services }
  let(:group_bugowner) { create(:group, title: 'senseless_group') }
  let(:group) { create(:group, title: 'my_test_group') }
  let(:other_user) { create(:confirmed_user, login: 'other_user') }
  let(:other_user2) { create(:confirmed_user, login: 'other_user2') }
  let(:other_user3) { create(:confirmed_user, login: 'other_user3') }
  let(:fake_multibuild_results) do
    Buildresult.new(
      '<resultlist state="b006a28328744bf1186d2b6fb3006ecb">
        <result project="home:tom" repository="openSUSE_Tumbleweed" arch="i586" code="finished" state="finished">
          <status package="test_package" code="excluded" />
          <status package="test_package:test_package-source" code="succeeded" />
        </result>
        <result project="home:tom" repository="openSUSE_Tumbleweed" arch="x86_64" code="building" state="building">
          <status package="test_package" code="building" />
          <status package="test_package:test_package-source" code="unresolvable" />
        </result>
        <result project="home:tom" repository="openSUSE_Leap_42.2" arch="x86_64" code="finished" state="finished">
          <status package="test_package" code="succeded" />
          <status package="test_package:test_package-source" code="disabled" />
        </result>
      </resultlist>')
  end

  context '#save_file' do
    before do
      login(user)
    end

    it 'calls #addKiwiImport if filename ends with kiwi.txz' do
      expect_any_instance_of(Service).to receive(:addKiwiImport).once
      package.save_file({ filename: 'foo.kiwi.txz' })
    end

    it 'does not call #addKiwiImport if filename ends not with kiwi.txz' do
      expect_any_instance_of(Service).not_to receive(:addKiwiImport)
      package.save_file({ filename: 'foo.spec' })
    end
  end

  context "is_admin?" do
    it "returns true for admins" do
      expect(admin.is_admin?).to be true
    end

    it "returns false for non-admins" do
      expect(user.is_admin?).to be false
    end
  end

  context '#delete_file' do
    let(:url) { "#{CONFIG['source_url']}/source/#{home_project.name}/#{package_with_file.name}" }

    before do
      login(user)
    end

    context 'with delete permission' do
      context 'with default options' do
        before do
          package_with_file.delete_file('somefile.txt')
        end

        it 'deletes file' do
          expect {
            package_with_file.source_file('somefile.txt')
          }.to raise_error(ActiveXML::Transport::NotFoundError)
        end

        it 'sets options correct' do
          expect(a_request(:delete, "#{url}/somefile.txt?user=#{user.login}")).to have_been_made.once
        end
      end

      context 'with custom options' do
        before do
          package_with_file.delete_file('somefile.txt', { comment: 'comment' })
        end

        it 'sets options correct' do
          expect(a_request(:delete, "#{url}/somefile.txt?comment=comment&user=#{user.login}")).to have_been_made.once
        end
      end
    end

    context 'with no delete permission' do
      let(:other_user) { create(:user) }

      before do
        login(other_user)
      end

      it 'raises DeleteFileNoPermission exception' do
        expect {
          package_with_file.delete_file('somefile.txt')
        }.to raise_error(DeleteFileNoPermission)
      end

      it 'does not delete file' do
        expect {
          package_with_file.source_file('somefile.txt')
        }.to_not raise_error
      end
    end

    context 'file not found' do
      it 'raises NotFoundError' do
        expect {
          package_with_file.source_file('not_existent.txt')
        }.to raise_error(ActiveXML::Transport::NotFoundError)
      end
    end
  end

  context '#maintainers' do
    before do
      login(user)
    end

    it 'returns an array with user objects to all maintainers for a package' do
      # first of all, we add a user who is not a maintainer but a bugowner
      # he/she should not be recognized by package.maintainers
      create(:relationship_package_user_as_bugowner, user: other_user2, package: package)

      # we expect both users to be in that returning array
      create(:relationship_package_user, user: user, package: package)
      create(:relationship_package_user, user: other_user, package: package)

      expect(package.maintainers).to match_array([other_user, user])
    end

    it 'resolves groups properly' do
      # groups should be resolved and only their assigned users should be in the
      # returning array
      group.add_user(other_user)
      group.add_user(other_user2)

      # add a group to the package what is not a maintainer to make sure it'll
      # be ignored when calling package.maintainers
      group_bugowner.add_user(other_user3)

      create(:relationship_package_group_as_bugowner, group: group_bugowner, package: package)
      create(:relationship_package_group, group: group, package: package)

      expect(package.maintainers).to match_array([other_user, other_user2])
    end

    it 'makes sure that no user is listed more than one time' do
      group.add_user(user)
      group_bugowner.add_user(user)

      create(:relationship_package_group, group: group, package: package)
      create(:relationship_package_group, group: group_bugowner, package: package)
      create(:relationship_package_user, user: user, package: package)

      expect(package.maintainers).to match_array([user])
    end

    it 'returns users and the users of resolved groups' do
      group.add_user(user)
      group_bugowner.add_user(other_user)

      create(:relationship_package_group, group: group, package: package)
      create(:relationship_package_group, group: group_bugowner, package: package)
      create(:relationship_package_user, user: other_user2, package: package)

      expect(package.maintainers).to match_array([user, other_user, other_user2])
    end
  end

  context '#file_exists?' do
    context 'with more than one file' do
      it 'returns true if the file exist' do
        expect(package_with_file.file_exists?('somefile.txt')).to eq(true)
      end

      it 'returns false if the file does not exist' do
        expect(package_with_file.file_exists?('not_existent.txt')).to eq(false)
      end
    end

    context 'with one file' do
      let(:package_with_one_file) { create(:package_with_service, name: 'package_with_one_file', project: home_project) }

      it 'returns true if the file exist' do
        expect(package_with_one_file.file_exists?('_service')).to eq(true)
      end

      it 'returns false if the file does not exist' do
        expect(package_with_one_file.file_exists?('not_existent.txt')).to eq(false)
      end
    end
  end

  context '#has_icon?' do
    it 'returns true if the icon exist' do
      if CONFIG['global_write_through']
        Suse::Backend.put("/source/#{CGI.escape(package_with_file.project.name)}/#{CGI.escape(package_with_file.name)}/_icon", Faker::Lorem.paragraph)
      end
      expect(package_with_file.has_icon?).to eq(true)
    end

    it 'returns false if the icon does not exist' do
      expect(package.has_icon?).to eq(false)
    end
  end

  describe '#service_error' do
    context 'without error' do
      it { expect(package_with_service.service_error).to be_nil }
    end
    context 'with error' do
      it { expect(package_with_broken_service.service_error).not_to be_empty }
    end
  end

  describe '#self.valid_name?' do
    context "invalid" do
      it{ expect(Package.valid_name?(10)).to be(false) }

      it "has an invalid character in first position" do
        property_of {
          string = sized(1){ string(/[-+_\.]/) } + sized(range(0, 199)){ string(/[-+\w\.]/) }
          guard string !~ /^(_product|_product:\w|_patchinfo|_patchinfo:\w|_pattern|_project)/
          string
        }.check { |string|
          expect(Package.valid_name?(string)).to be(false)
        }
      end

      it "has more than 200 characters" do
        property_of {
          sized(1){ string(/[a-zA-Z0-9]/) } + sized(200) { string(/[-+\w\.:]/) }
        }.check(3) { |string|
          expect(Package.valid_name?(string)).to be(false)
        }
      end

      it{ expect(Package.valid_name?('0')).to be(false) }
      it{ expect(Package.valid_name?('')).to be(false) }
    end

    context "valid" do
      it "general case" do
        property_of {
          string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 199)) { string(/[-+\w\.]/) }
          guard string != '0'
          string
        }.check { |string|
          expect(Package.valid_name?(string)).to be(true)
        }
      end

      it "starts with '_product:'" do
        property_of {
          string = '_product:' + sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 190)) { string(/[-+\w\.]/) }
          guard string != '0'
          string
        }.check(3) { |string|
          expect(Package.valid_name?(string)).to be(true)
        }
      end

      it "starts with '_patchinfo:'" do
        property_of {
          string = '_patchinfo:' + sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 188)) { string(/[-+\w\.]/) }
          guard string != '0'
          string
        }.check(3) { |string|
          expect(Package.valid_name?(string)).to be(true)
        }
      end

      it{ expect(Package.valid_name?('_product')).to be(true) }
      it{ expect(Package.valid_name?('_pattern')).to be(true) }
      it{ expect(Package.valid_name?('_project')).to be(true) }
      it{ expect(Package.valid_name?('_patchinfo')).to be(true) }
    end
  end

  # WARNING: "#The buildresults" test has been stubbed because,
  # in order to make it work without stubs it would be needed
  # to mock the scheduler as it is done in the old test suite.
  #
  # The following code would be needed to get this working
  # once we have a scheduler running in this test suite:
  #
  # user2 = create(:confirmed_user, login: 'usuario_prueba')
  # login user2
  # user2_home_project = user2.home_project
  #
  # home_project_repo = create(:repository, name: 'user2_home_project_repo', project: user2_home_project, architectures: ['i586'])
  #
  # project2 = create(:project, name: 'project2')
  # project2.config.save({}, 'Type: spec')
  # project2_repo = create(:repository, name: 'project2_repo', project: project2, architectures: ['i586'])
  #
  # create(:path_element, repository: home_project_repo, link: project2_repo)
  # user2_home_project.store
  #
  # package_locallink = create(:package, name: 'locallink', project: user2_home_project)
  #
  # results = package_locallink.buildresults
  #
  context "#buildresults" do
    let(:results) { package.buildresults }
    let(:results_test_package) { results['test_package'] }
    let(:results_test_package_source) { results['test_package:test_package-source'] }

    before do
      allow(Buildresult).to receive(:find).and_return(fake_multibuild_results)
    end

    it { expect(results.keys).to match_array(['test_package', 'test_package:test_package-source']) }

    it { expect(results_test_package.length).to eq(3) }

    it { expect(results_test_package.first.repository).to eq('openSUSE_Leap_42.2') }
    it { expect(results_test_package.first.architecture).to eq('x86_64') }
    it { expect(results_test_package.first.code).to eq('succeded') }
    it { expect(results_test_package.first.state).to eq('finished') }
    it { expect(results_test_package.first.details).to be_nil }

    it { expect(results_test_package_source.length).to eq(3) }

    it { expect(results_test_package_source.first.repository).to eq('openSUSE_Leap_42.2') }
    it { expect(results_test_package_source.first.architecture).to eq('x86_64') }
    it { expect(results_test_package_source.first.code).to eq('disabled') }
    it { expect(results_test_package_source.first.state).to eq('finished') }
    it { expect(results_test_package_source.first.details).to be_nil }
  end

  context '#source_path' do
    it { expect(package_with_file.source_path).to eq('/source/home:tom/package_with_files') }
    it { expect(package_with_file.source_path('icon')).to eq('/source/home:tom/package_with_files/icon') }
    it { expect(package_with_file.source_path('icon', { format: :html})).to eq('/source/home:tom/package_with_files/icon?format=html') }
  end

  context '#public_source_path' do
    it { expect(package_with_file.public_source_path).to eq('/public/source/home:tom/package_with_files') }
    it { expect(package_with_file.public_source_path('icon')).to eq('/public/source/home:tom/package_with_files/icon') }
    it { expect(package_with_file.public_source_path('icon', { format: :html})).to eq('/public/source/home:tom/package_with_files/icon?format=html') }
  end
end
