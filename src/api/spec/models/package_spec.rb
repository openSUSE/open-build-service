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
        Backend::Connection.put("/source/#{CGI.escape(package_with_file.project.name)}/#{CGI.escape(package_with_file.name)}/_icon",
                                Faker::Lorem.paragraph)
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
          string = sized(1) { string(/[-+_\.]/) } + sized(range(0, 199)) { string(/[-+\w\.]/) }
          guard string !~ /^(_product|_product:\w|_patchinfo|_patchinfo:\w|_pattern|_project)/
          string
        }.check { |string|
          expect(Package.valid_name?(string)).to be(false)
        }
      end

      it "has more than 200 characters" do
        property_of {
          sized(1) { string(/[a-zA-Z0-9]/) } + sized(200) { string(/[-+\w\.:]/) }
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

  describe '.what_depends_on' do
    let(:repository) { 'openSUSE_Leap_42.1'}
    let(:architecture) { 'x86_64' }
    let(:parameter) { "package=#{package.name}&view=revpkgnames" }
    let(:url) { "#{CONFIG['source_url']}/build/#{package.project}/#{repository}/#{architecture}/_builddepinfo?#{parameter}" }
    let(:result) { Package.what_depends_on(package.project, package, repository, architecture) }
    let(:no_dependency) { "<builddepinfo />" }

    it 'builds backend path correct' do
      stub_request(:get, url).and_return(body: no_dependency)
      Package.what_depends_on(package.project, package, repository, architecture)
      expect(a_request(:get, url)).to have_been_made.once
    end

    context 'with no build dependencies' do
      before do
        stub_request(:get, url).and_return(body: no_dependency)
      end

      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end

    context 'with one build dependency' do
      let(:one_dependency) do
        "<builddepinfo>" +
          "<package name=\"gcc6\">" +
            "<pkgdep>gcc</pkgdep>" +
          "</package>" +
        "</builddepinfo>"
      end

      before do
        stub_request(:get, url).and_return(body: one_dependency)
      end

      it 'returns an array with the dependency' do
        expect(result).to eq(['gcc'])
      end
    end

    context 'with more than one build dependency' do
      let(:two_dependencies) do
        "<builddepinfo>" +
          "<package name=\"gcc\">" +
            "<pkgdep>gcc6</pkgdep>" +
            "<pkgdep>xz</pkgdep>" +
          "</package>" +
        "</builddepinfo>"
      end

      before do
        stub_request(:get, url).and_return(body: two_dependencies)
      end

      it 'returns an array with the dependencies' do
        expect(result).to eq(['gcc6', 'xz'])
      end
    end

    context 'with invalid repository or architecture' do
      before do
        allow(Backend::Connection).to receive(:get).and_raise(ActiveXML::Transport::NotFoundError.new('message'))
      end

      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end
  end

  describe '#backend_build_command' do
    let(:params) { ActionController::Parameters.new(arch: 'x86') }
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{package.project.name}?cmd=rebuild&arch=x86" }

    subject { package.backend_build_command(:rebuild, package.project.name, params) }

    context 'backend response is successful' do
      before { stub_request(:post, backend_url) }

      it { is_expected.to be_truthy }
    end

    context 'backend response fails' do
      before { stub_request(:post, backend_url).and_raise(ActiveXML::Transport::Error) }

      it { is_expected.to be_falsey }
    end

    context 'user has no access rights for the project' do
      let(:other_project) { create(:project) }

      before do
        # check_write_access! depends on the Rails env. We have to workaround this here.
        allow(Rails.env).to receive(:test?).and_return false
        # also check_write_access! relies on User.current
        login(user)

        allow(Backend::Connection).to receive(:post).never
      end

      subject { package.backend_build_command(:rebuild, other_project.name, params) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#jobhistory_list' do
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{home_project}/openSUSE_Tumbleweed/x86_64/_jobhistory?package=#{package}&limit=100" }

    subject { package.jobhistory_list(home_project, 'openSUSE_Tumbleweed', 'x86_64') }

    context 'when response is successful' do
      let(:local_job_history) do
        { revision:      '1',
          srcmd5:        '2ac8bd685591b40e412ee99b182f94c2',
          build_counter: '1',
          worker_id:     'vagrant-openSUSE-Leap:1',
          host_arch:     'x86_64',
          reason:        'new build',
          ready_time:    1_492_687_344,
          start_time:    1_492_687_470,
          end_time:      1_492_687_507,
          total_time:    37,
          code:          'succeed' }
      end

      before do
        stub_request(:get, backend_url).and_return(body:
        %(<jobhistlist>
          <jobhist package='#{package.name}' rev='1' srcmd5='2ac8bd685591b40e412ee99b182f94c2' versrel='7-3' bcnt='1' readytime='1492687344'
          starttime='1492687470' endtime='1492687507' code='succeed' uri='http://127.0.0.1:41355' workerid='vagrant-openSUSE-Leap:1'
          hostarch='x86_64' reason='new build' verifymd5='2ac8bd685591b40e412ee99b182f94c2'/>
        </jobhistlist>))
      end

      it { expect(subject.class).to eq(Array) }
      it { expect(subject.first.class).to eq(LocalJobHistory) }
      it { expect(subject.first).to have_attributes(local_job_history) }
    end

    context 'when response fails' do
      before { stub_request(:get, backend_url).and_raise(ActiveXML::Transport::NotFoundError) }

      it { is_expected.to eq([]) }
    end
  end

  describe '#last_build_reason' do
    let(:path) { "#{CONFIG['source_url']}/build/#{package.project.name}/openSUSE_Leap_42.3/x86_64/#{package.name}/_reason" }

    before do
      stub_request(:get, path).and_return(body:
        %(<reason>\n  <explain>source change</explain>  <time>1496387771</time>  <oldsource>1de56fdc419ea4282e35bd388285d370</oldsource></reason>))
    end

    let(:result) { package.last_build_reason("openSUSE_Leap_42.3", "x86_64") }

    it 'returns a PackageBuildReason object' do
      expect(result).to be_a(PackageBuildReason)
    end

    context 'validation of data' do
      it 'for: explain' do
        expect(result.explain).to eq('source change')
      end

      it 'for: time' do
        expect(result.time).to eq('1496387771')
      end

      it 'for: oldsource' do
        expect(result.oldsource).to eq('1de56fdc419ea4282e35bd388285d370')
      end

      it 'for: packagechange (one element)' do
        stub_request(:get, path).and_return(body:
          %(<reason>\n  <explain>source change</explain>  <time>1496387771</time>  <oldsource>1de56fdc419ea4282e35bd388285d370</oldsource>
            <packagechange change="md5sum" key="libsystemd0-mini"/></reason>))
        result = package.last_build_reason("openSUSE_Leap_42.3", "x86_64")

        expect(result.packagechange).to eq(
          [
            {
              'change' => 'md5sum',
              'key'    => 'libsystemd0-mini'
            }
          ]
        )
      end

      it 'for: packagechange (multiple elements)' do
        stub_request(:get, path).and_return(body:
          %(<reason>\n  <explain>source change</explain>  <time>1496387771</time>  <oldsource>1de56fdc419ea4282e35bd388285d370</oldsource>
            <packagechange change="md5sum" key="libsystemd0-mini"/><packagechange change="md5sum" key="python3-websockets"/></reason>))
        result = package.last_build_reason("openSUSE_Leap_42.3", "x86_64")

        expect(result.packagechange).to eq(
          [
            {
              'change' => 'md5sum',
              'key'    => 'libsystemd0-mini'
            },
            {
              'change' => 'md5sum',
              'key'    => 'python3-websockets'
            }
          ]
        )
      end
    end
  end
end
