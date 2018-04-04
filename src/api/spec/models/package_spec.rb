require 'rails_helper'
require 'webmock/rspec'
require 'rantly/rspec_extensions'
# WARNING: If you change #file_exists or #has_file test make sure
# you uncomment the next line and start a test backend.
# CONFIG['global_write_through'] = true

# rubocop:disable Metrics/BlockLength
RSpec.describe Package, vcr: true do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:home_project) { user.home_project }
  let(:package) { create(:package, name: 'test_package', project: home_project) }
  let(:package_with_file) { create(:package_with_file, name: 'package_with_files', project: home_project) }
  let(:package_with_broken_service) { create(:package_with_broken_service, name: 'package_with_broken_service', project: home_project) }
  let(:package_with_service) { create(:package_with_service, name: 'package_with_service', project: home_project) }
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
        <result project="home:Admin" repository="images" arch="i586" code="published" state="published">
          <status package="test_package_image" code="broken">
            <details>can not parse package name from test_package_image.kiwi because: repo url not using obs:/ scheme: http://download.opensuse.org/update/leap/42.1/oss/
</details>
          </status>
        </result>
        <result project="home:Admin" repository="images" arch="x86_64" code="published" state="published">
          <status package="test_package_image" code="broken">
            <details>can not parse package name from test_package_image.kiwi because: repo url not using obs:/ scheme: http://download.opensuse.org/update/leap/42.1/oss/
</details>
          </status>
        </result>
        <result project="home:Admin" repository="home_Admin_images" arch="i586" code="published" state="published">
          <status package="test_package_image" code="broken">
            <details>can not parse package name from test_package_image.kiwi because: repo url not using obs:/ scheme: http://download.opensuse.org/update/leap/42.1/oss/
</details>
          </status>
        </result>
        <result project="home:Admin" repository="home_Admin_images" arch="x86_64" code="published" state="published">
          <status package="test_package_image" code="broken">
            <details>can not parse package name from test_package_image.kiwi because: repo url not using obs:/ scheme: http://download.opensuse.org/update/leap/42.1/oss/
</details>
          </status>
        </result>
      </resultlist>'
    )
  end

  before do
    login(user)
  end

  context '#save_file' do
    it 'calls #addKiwiImport if filename ends with kiwi.txz' do
      expect_any_instance_of(Service).to receive(:addKiwiImport).once
      package.save_file(filename: 'foo.kiwi.txz')
    end

    it 'does not call #addKiwiImport if filename ends not with kiwi.txz' do
      expect_any_instance_of(Service).not_to receive(:addKiwiImport)
      package.save_file(filename: 'foo.spec')
    end
  end

  context 'is_admin?' do
    it 'returns true for admins' do
      expect(admin.is_admin?).to be true
    end

    it 'returns false for non-admins' do
      expect(user.is_admin?).to be false
    end
  end

  context '#delete_file' do
    let(:url) { "#{CONFIG['source_url']}/source/#{home_project.name}/#{package_with_file.name}" }

    context 'with delete permission' do
      context 'with default options' do
        before do
          package_with_file.delete_file('somefile.txt')
        end

        it 'deletes file' do
          expect do
            package_with_file.source_file('somefile.txt')
          end.to raise_error(ActiveXML::Transport::NotFoundError)
        end

        it 'sets options correct' do
          expect(a_request(:delete, "#{url}/somefile.txt?user=#{user.login}")).to have_been_made.once
        end
      end

      context 'with custom options' do
        before do
          package_with_file.delete_file('somefile.txt', comment: 'comment')
        end

        it 'sets options correct' do
          expect(a_request(:delete, "#{url}/somefile.txt?comment=comment&user=#{user.login}")).to have_been_made.once
        end
      end
    end

    context 'with no delete permission' do
      before do
        login(other_user)
      end

      it 'raises DeleteFileNoPermission exception' do
        expect do
          package_with_file.delete_file('somefile.txt')
        end.to raise_error(DeleteFileNoPermission)
      end

      it 'does not delete file' do
        expect do
          package_with_file.source_file('somefile.txt')
        end.not_to raise_error
      end
    end

    context 'file not found' do
      it 'raises NotFoundError' do
        expect do
          package_with_file.source_file('not_existent.txt')
        end.to raise_error(ActiveXML::Transport::NotFoundError)
      end
    end
  end

  context '#maintainers' do
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
    context 'invalid' do
      it { expect(Package.valid_name?(10)).to be(false) }

      it 'has an invalid character in first position' do
        property_of do
          string = sized(1) { string(/[-+_\.]/) } + sized(range(0, 199)) { string(/[-+\w\.]/) }
          guard string !~ /^(_product|_product:\w|_patchinfo|_patchinfo:\w|_pattern|_project)/
          string
        end.check do |string|
          expect(Package.valid_name?(string)).to be(false)
        end
      end

      it 'has more than 200 characters' do
        property_of do
          sized(1) { string(/[a-zA-Z0-9]/) } + sized(200) { string(/[-+\w\.:]/) }
        end.check(3) do |string|
          expect(Package.valid_name?(string)).to be(false)
        end
      end

      it { expect(Package.valid_name?('0')).to be(false) }
      it { expect(Package.valid_name?('')).to be(false) }
    end

    context 'valid' do
      it 'general case' do
        property_of do
          string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 199)) { string(/[-+\w\.]/) }
          guard string != '0'
          string
        end.check do |string|
          expect(Package.valid_name?(string)).to be(true)
        end
      end

      it "starts with '_product:'" do
        property_of do
          string = '_product:' + sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 190)) { string(/[-+\w\.]/) }
          guard string != '0'
          string
        end.check(3) do |string|
          expect(Package.valid_name?(string)).to be(true)
        end
      end

      it "starts with '_patchinfo:'" do
        property_of do
          string = '_patchinfo:' + sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 188)) { string(/[-+\w\.]/) }
          guard string != '0'
          string
        end.check(3) do |string|
          expect(Package.valid_name?(string)).to be(true)
        end
      end

      it { expect(Package.valid_name?('_product')).to be(true) }
      it { expect(Package.valid_name?('_pattern')).to be(true) }
      it { expect(Package.valid_name?('_project')).to be(true) }
      it { expect(Package.valid_name?('_patchinfo')).to be(true) }
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
  context '#buildresults' do
    let(:results_test_package) { results['test_package'] }
    let(:results_test_package_source) { results['test_package:test_package-source'] }
    let(:results_test_package_image) { results['test_package_image'] }
    before do
      allow(Buildresult).to receive(:find).and_return(fake_multibuild_results)
    end

    context 'without entries in state "excluded"' do
      let(:results) do
        results, _excluded_number = package.buildresults(home_project, false)
        results
      end

      it { expect(results.keys).to match_array(['test_package', 'test_package:test_package-source', 'test_package_image']) }

      it { expect(results_test_package.length).to eq(2) }

      it { expect(results_test_package.first.repository).to eq('openSUSE_Leap_42.2') }
      it { expect(results_test_package.first.architecture).to eq('x86_64') }
      it { expect(results_test_package.first.code).to eq('succeded') }
      it { expect(results_test_package.first.state).to eq('finished') }
      it { expect(results_test_package.first.details).to be_nil }
      it { expect(results_test_package.last.repository).to eq('openSUSE_Tumbleweed') }
      it { expect(results_test_package.last.architecture).to eq('x86_64') }
      it { expect(results_test_package.last.code).to eq('building') }
      it { expect(results_test_package.last.state).to eq('building') }
      it { expect(results_test_package.last.details).to be_nil }

      it { expect(results_test_package_source.length).to eq(3) }

      it { expect(results_test_package_source.first.repository).to eq('openSUSE_Leap_42.2') }
      it { expect(results_test_package_source.first.architecture).to eq('x86_64') }
      it { expect(results_test_package_source.first.code).to eq('disabled') }
      it { expect(results_test_package_source.first.state).to eq('finished') }
      it { expect(results_test_package_source.first.details).to be_nil }

      it { expect(results_test_package_image.length).to eq(4) }

      it { expect(results_test_package_image.first.repository).to eq('home_Admin_images') }
      it { expect(results_test_package_image.first.architecture).to eq('i586') }
      it { expect(results_test_package_image.first.code).to eq('broken') }
      it { expect(results_test_package_image.first.state).to eq('published') }
      it { expect(results_test_package_image.first.details).not_to be_nil }
    end

    context 'with entries in state "excluded"' do
      let(:results) do
        results, _excluded_number = package.buildresults(home_project, true)
        results
      end

      it { expect(results.keys).to match_array(['test_package', 'test_package:test_package-source', 'test_package_image']) }
      it { expect(results_test_package.length).to eq(3) }

      it { expect(results_test_package.first.repository).to eq('openSUSE_Leap_42.2') }
      it { expect(results_test_package.first.architecture).to eq('x86_64') }
      it { expect(results_test_package.first.code).to eq('succeded') }
      it { expect(results_test_package.first.state).to eq('finished') }
      it { expect(results_test_package.first.details).to be_nil }

      it { expect(results_test_package.second.repository).to eq('openSUSE_Tumbleweed') }
      it { expect(results_test_package.second.architecture).to eq('i586') }
      it { expect(results_test_package.second.code).to eq('excluded') }
      it { expect(results_test_package.second.state).to eq('finished') }
      it { expect(results_test_package.second.details).to be_nil }

      it { expect(results_test_package.last.repository).to eq('openSUSE_Tumbleweed') }
      it { expect(results_test_package.last.architecture).to eq('x86_64') }
      it { expect(results_test_package.last.code).to eq('building') }
      it { expect(results_test_package.last.state).to eq('building') }
      it { expect(results_test_package.last.details).to be_nil }

      it { expect(results_test_package_source.length).to eq(3) }
      it { expect(results_test_package_image.length).to eq(4) }
    end
  end

  context '#source_path' do
    it { expect(package_with_file.source_path).to eq('/source/home:tom/package_with_files') }
    it { expect(package_with_file.source_path('icon')).to eq('/source/home:tom/package_with_files/icon') }
    it { expect(package_with_file.source_path('icon', format: :html)).to eq('/source/home:tom/package_with_files/icon?format=html') }
  end

  context '#public_source_path' do
    it { expect(package_with_file.public_source_path).to eq('/public/source/home:tom/package_with_files') }
    it { expect(package_with_file.public_source_path('icon')).to eq('/public/source/home:tom/package_with_files/icon') }
    it 'adds the format parameter to the url that was given to the method' do
      expect(package_with_file.public_source_path('icon', format: :html)).to eq('/public/source/home:tom/package_with_files/icon?format=html')
    end
  end

  describe '.what_depends_on' do
    let(:repository) { 'openSUSE_Leap_42.1' }
    let(:architecture) { 'x86_64' }
    let(:parameter) { "package=#{package.name}&view=revpkgnames" }
    let(:url) { "#{CONFIG['source_url']}/build/#{package.project}/#{repository}/#{architecture}/_builddepinfo?#{parameter}" }
    let(:result) { Package.what_depends_on(package.project, package, repository, architecture) }
    let(:no_dependency) { '<builddepinfo />' }

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
        '<builddepinfo>' \
          '<package name="gcc6">' \
          '<pkgdep>gcc</pkgdep>' \
          '</package>' \
          '</builddepinfo>'
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
        '<builddepinfo>' \
          '<package name="gcc">' \
          '<pkgdep>gcc6</pkgdep>' \
          '<pkgdep>xz</pkgdep>' \
          '</package>' \
          '</builddepinfo>'
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
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{package.project.name}?arch=x86&cmd=rebuild" }

    subject { package.backend_build_command(:rebuild, package.project.name, params) }

    context 'backend response is successful' do
      before { stub_request(:post, backend_url) }

      it { is_expected.to be_truthy }

      it 'has no errors' do
        subject
        expect(package.errors.details).to eq({})
      end
    end

    context 'backend response fails' do
      before { stub_request(:post, backend_url).and_raise(ActiveXML::Transport::Error) }

      it { is_expected.to be_falsey }

      it 'has errors' do
        subject
        expect(package.errors.details).to eq(base: [{ error: 'Exception from WebMock' }])
      end
    end

    context 'user has no access rights for the project' do
      let(:other_project) { create(:project, name: 'other_project') }

      before do
        # check_write_access! depends on the Rails env. We have to workaround this here.
        allow(Rails.env).to receive(:test?).and_return false

        allow(Backend::Connection).to receive(:post).never
      end

      subject { package.backend_build_command(:rebuild, other_project.name, params) }

      it { is_expected.to be_falsey }

      it 'has errors' do
        subject
        expect(package.errors.details).to eq(base: [{ error: "No permission to modify project '#{other_project}' for user '#{user}'" }])
      end
    end
  end

  describe '#jobhistory_list' do
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{home_project}/openSUSE_Tumbleweed/x86_64/_jobhistory?limit=100&package=#{package}" }

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
          <jobhist package='#{package.name}' rev='2' srcmd5='597d297d19621de7db926d36d27d4331' versrel='7-3' bcnt='1' readytime='1492687344'
          starttime='1492687470' endtime='1492687507' code='succeed' uri='http://127.0.0.1:41355' workerid='vagrant-openSUSE-Leap:1'
          hostarch='x86_64' reason='source change' verifymd5='597d297d19621de7db926d36d27d4331'/>
        </jobhistlist>))
      end

      it { expect(subject.last).to have_attributes(local_job_history) }

      it 'returns the jobs in descending order' do
        expect(subject[0].revision).to eq('2')
        expect(subject[1].revision).to eq('1')
      end

      it 'contains the previous srcmd5 value on the job with rev=2' do
        expect(subject[0].srcmd5).to eq('597d297d19621de7db926d36d27d4331')
        expect(subject[0].prev_srcmd5).to eq('2ac8bd685591b40e412ee99b182f94c2')
      end
    end

    context 'when response fails' do
      before { stub_request(:get, backend_url).and_raise(ActiveXML::Transport::NotFoundError) }

      it { is_expected.to eq([]) }
    end
  end

  describe '#meta' do
    it 'returns a PackageMetaFile object' do
      expect(package.meta).to be_a(PackageMetaFile)
    end

    it 'has the correct project name set' do
      expect(package.meta.project_name).to eq(package.project.name)
    end

    it 'has the correct package name set' do
      expect(package.meta.package_name).to eq(package.name)
    end
  end

  describe '#last_build_reason' do
    let(:path) { "#{CONFIG['source_url']}/build/#{package.project.name}/openSUSE_Leap_42.3/x86_64/#{package.name}/_reason" }

    before do
      stub_request(:get, path).and_return(body:
        %(<reason>\n  <explain>source change</explain>  <time>1496387771</time>  <oldsource>1de56fdc419ea4282e35bd388285d370</oldsource></reason>))
    end

    let(:result) { package.last_build_reason('openSUSE_Leap_42.3', 'x86_64') }

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
        result = package.last_build_reason('openSUSE_Leap_42.3', 'x86_64')

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
        result = package.last_build_reason('openSUSE_Leap_42.3', 'x86_64')

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

  describe '.kiwi_image_outdated?' do
    context 'without a kiwi_image' do
      it { expect(package.kiwi_image_outdated?).to be(true) }
    end

    context 'with a kiwi_image' do
      let(:kiwi_image_with_package_with_kiwi_file) do
        create(:kiwi_image_with_package, project: home_project, package_name: 'package_with_kiwi_file', with_kiwi_file: true)
      end

      context 'with same md5' do
        it { expect(kiwi_image_with_package_with_kiwi_file.package.kiwi_image_outdated?).to be(false) }
      end

      context 'with different md5' do
        before do
          kiwi_image_with_package_with_kiwi_file.md5_last_revision = 'FAKE md5'
          kiwi_image_with_package_with_kiwi_file.save
        end

        it { expect(kiwi_image_with_package_with_kiwi_file.package.kiwi_image_outdated?).to be(true) }
      end
    end
  end

  describe '#sources_changed' do
    let!(:project) { create(:project, name: 'apache') }
    let!(:package) { create(:package_with_file, name: 'mod_ssl', project: project) }

    subject { package.sources_changed }

    it 'creates a BackendPackge for the Package' do
      expect { subject }.to change(BackendPackage, :count).by(1)
    end
  end

  describe '#commit_message' do
    let(:changes_file) do
      '-------------------------------------------------------------------
Wed Aug  2 14:59:15 UTC 2017 - iggy@opensuse.org

- Temporary hack'
    end

    let(:project) { create(:project, name: 'home:foo:Apache') }
    let(:package) { create(:package_with_changes_file, project: project, name: 'package_with_changes_file') }

    context 'with a diff to the target package changes file' do
      let(:target_project)  { create(:project, name: 'Apache') }
      let!(:target_package) do
        create(:package_with_changes_file, project: target_project, name: 'package_with_changes_file', changes_file_content: changes_file)
      end
      subject { package.commit_message(target_project, target_package) }

      it { expect(subject).to include('- Testing the submit diff') }
      it { expect(subject).not_to include('- Temporary hack') }
      it { expect(subject).not_to include('Fri Aug 11 16:58:15 UTC 2017 - tom@opensuse.org') }
      it { expect(subject).not_to include('Wed Aug  2 14:59:15 UTC 2017 - iggy@opensuse.org') }
      it { expect(subject).not_to include('-------------------------------------------------------------------') }
    end

    context 'with no diff to the target package changes file' do
      subject { package.commit_message(nil, nil) }

      it { expect(subject).to include('- Testing the submit diff') }
      it { expect(subject).to include('- Temporary hack') }
      it { expect(subject).not_to include('Fri Aug 11 16:58:15 UTC 2017 - tom@opensuse.org') }
      it { expect(subject).not_to include('Wed Aug  2 14:59:15 UTC 2017 - iggy@opensuse.org') }
      it { expect(subject).not_to include('-------------------------------------------------------------------') }
    end

    context 'of a package without a changes file' do
      let(:package) { create(:package, project: project, name: 'apache2') }

      it { expect(package.commit_message(nil, nil)).to eq('') }
    end

    context 'of a package with more than one changes file' do
      before do
        if CONFIG['global_write_through']
          full_path = "/source/#{package.project.name}/#{package.name}/lorem.changes"
          Backend::Connection.put(URI.escape(full_path), 'Lorem ipsum dolorem')
        end
      end

      it { expect(package.commit_message(nil, nil)).to include('Lorem ipsum dolorem') }
    end
  end

  describe '#add_maintainer' do
    subject { package }

    it_behaves_like 'makes a user a maintainer of the subject'
  end
end
# rubocop:enable Metrics/BlockLength
