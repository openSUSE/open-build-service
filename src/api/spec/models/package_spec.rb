require 'webmock/rspec'
require 'rantly/rspec_extensions'

RSpec.describe Package, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
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

  before do
    login(user)
  end

  describe '#save_file' do
    it 'calls #add_kiwi_import if filename ends with kiwi.txz' do
      expect_any_instance_of(Service).to receive(:add_kiwi_import).once
      package.save_file(filename: 'foo.kiwi.txz')
    end

    it 'does not call #add_kiwi_import if filename ends not with kiwi.txz' do
      expect_any_instance_of(Service).not_to receive(:add_kiwi_import)
      package.save_file(filename: 'foo.spec')
    end
  end

  describe '#delete_file' do
    let(:url) { "#{CONFIG['source_url']}/source/#{home_project.name}/#{package_with_file.name}" }

    context 'with delete permission' do
      context 'with default options' do
        before do
          package_with_file.delete_file('somefile.txt')
        end

        it 'deletes file' do
          expect do
            package_with_file.source_file('somefile.txt')
          end.to raise_error(Backend::NotFoundError)
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
        end.to raise_error(Backend::NotFoundError)
      end
    end
  end

  describe '#maintainers' do
    it 'returns an array with user objects to all maintainers for a package' do
      # first of all, we add a user who is not a maintainer but a bugowner
      # they should not be recognized by package.maintainers
      create(:relationship_package_user_as_bugowner, user: other_user2, package: package)

      # we expect both users to be in that returning array
      create(:relationship_package_user, user: user, package: package)
      create(:relationship_package_user, user: other_user, package: package)

      expect(package.maintainers).to contain_exactly(other_user, user)
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

      expect(package.maintainers).to contain_exactly(other_user, other_user2)
    end

    it 'makes sure that no user is listed more than one time' do
      group.add_user(user)
      group_bugowner.add_user(user)

      create(:relationship_package_group, group: group, package: package)
      create(:relationship_package_group, group: group_bugowner, package: package)
      create(:relationship_package_user, user: user, package: package)

      expect(package.maintainers).to contain_exactly(user)
    end

    it 'returns users and the users of resolved groups' do
      group.add_user(user)
      group_bugowner.add_user(other_user)

      create(:relationship_package_group, group: group, package: package)
      create(:relationship_package_group, group: group_bugowner, package: package)
      create(:relationship_package_user, user: other_user2, package: package)

      expect(package.maintainers).to contain_exactly(user, other_user, other_user2)
    end
  end

  describe '#file_exists?' do
    context '_multibuild file should exist' do
      let!(:multibuild_package) { create(:multibuild_package, name: 'test', project: home_project) }

      it { expect(multibuild_package.file_exists?('_multibuild')).to be(true) }
    end

    context 'with more than one file' do
      it 'returns true if the file exist' do
        expect(package_with_file.file_exists?('somefile.txt')).to be(true)
      end

      it 'returns false if the file does not exist' do
        expect(package_with_file.file_exists?('not_existent.txt')).to be(false)
      end
    end

    context 'with one file' do
      let(:package_with_one_file) { create(:package_with_service, name: 'package_with_one_file', project: home_project) }

      it 'returns true if the file exist' do
        expect(package_with_one_file.file_exists?('_service')).to be(true)
      end

      it 'returns false if the file does not exist' do
        expect(package_with_one_file.file_exists?('not_existent.txt')).to be(false)
      end
    end
  end

  describe '#icon?' do
    it 'returns true if the icon exist' do
      if CONFIG['global_write_through']
        Backend::Connection.put("/source/#{CGI.escape(package_with_file.project.name)}/#{CGI.escape(package_with_file.name)}/_icon",
                                Faker::Lorem.paragraph)
      end
      expect(package_with_file.icon?).to be(true)
    end

    it 'returns false if the icon does not exist' do
      expect(package.icon?).to be(false)
    end
  end

  describe '#service_error' do
    let(:url) { "#{CONFIG['source_url']}/source/#{package_with_service.project}/#{package_with_service.name}" }
    let(:no_error) do
      '<directory name="package_with_service" rev="1" vrev="1" srcmd5="cf9c84e27a27dfc3e289f74fb096b42a">
          <serviceinfo code="succeeded" xsrcmd5="ebd3257ae7a0170d10648c1a4ab4ce04" />
          <entry name="_service" md5="53b4f5c97c7a2122b964e5182c8325a2" size="11" mtime="1530259187" />
        </directory>'
    end
    let(:running) do
      '<directory name="package_with_service" rev="1" vrev="1" srcmd5="cf9c84e27a27dfc3e289f74fb096b42a">
         <serviceinfo code="running" />
        <entry name="_service" md5="53b4f5c97c7a2122b964e5182c8325a2" size="11" mtime="1526982880" />
     </directory>'
    end
    let(:remote_error) do
      '<directory name="package_with_service" rev="1" vrev="1" srcmd5="954749565ae2e0071b9cfaaa29acd2b1">
        <serviceinfo code="failed" xsrcmd5="b725a05beaf57fbf1ec85276efbcbf97">
          <error>service error:  400 remote error: document element must be \'services\', was \'service\'</error>
        </serviceinfo>
        <entry name="_service" md5="27a21c968dc9fadcab4da63af004add0" size="25" mtime="1530259187" />
      </directory>'
    end
    let(:service_error_url) { "#{CONFIG['source_url']}/source/#{package_with_service.project}/#{package_with_service.name}/_serviceerror?rev=b725a05beaf57fbf1ec85276efbcbf97" }
    let(:error) do
      "service daemon error:
         400 remote error: document element must be 'services', was 'service'"
    end

    it 'returns nil without errors' do
      stub_request(:get, url).and_return(body: no_error)
      expect(package_with_service.service_error).to be_nil
    end

    it 'returns nil on running' do
      stub_request(:get, url).and_return(body: running)
      expect(package_with_service.service_error).to be_nil
    end

    it 'returns the errors' do
      stub_request(:get, url).and_return(body: remote_error)
      stub_request(:get, service_error_url).and_return(body: error)
      expect(package_with_service.service_error).to match(error)
      expect(a_request(:get, service_error_url)).to have_been_made.once
    end
  end

  describe '#serviceinfo' do
    let(:url) { "#{CONFIG['source_url']}/source/#{package_with_service.project}/#{package_with_service.name}" }
    let(:no_serviceinfo) do
      '<directory name="package_with_service" rev="1" vrev="1" srcmd5="cf9c84e27a27dfc3e289f74fb096b42a">
          <entry name="_service" md5="53b4f5c97c7a2122b964e5182c8325a2" size="11" mtime="1530259187" />
        </directory>'
    end

    it 'returns empty hash' do
      stub_request(:get, url).and_return(body: no_serviceinfo)
      expect(package_with_service.serviceinfo).to eq({})
    end
  end

  describe '#self.valid_name?' do
    context 'invalid' do
      it { expect(Package.valid_name?(10)).to be(false) }

      it 'has an invalid character in first position' do
        property_of do
          string = sized(1) { string(/[-+_.]/) } + sized(range(0, 199)) { string(/[-+\w.]/) }
          guard(string !~ /^(_product|_product:\w|_patchinfo|_patchinfo:\w|_pattern|_project)/)
          string
        end.check do |string|
          expect(Package.valid_name?(string)).to be(false)
        end
      end

      it 'has more than 200 characters' do
        property_of do
          sized(1) { string(/[a-zA-Z0-9]/) } + sized(200) { string(/[-+\w.:]/) }
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
          string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 199)) { string(/[-+\w.]/) }
          guard(string != '0')
          string
        end.check do |string|
          expect(Package.valid_name?(string)).to be(true)
        end
      end

      it "starts with '_product:'" do
        property_of do
          string = "_product:#{sized(1) { string(/[a-zA-Z0-9]/) }}#{sized(range(0, 190)) { string(/[-+\w.]/) }}"
          guard(string != '0')
          string
        end.check(3) do |string|
          expect(Package.valid_name?(string)).to be(true)
        end
      end

      it "starts with '_patchinfo:'" do
        property_of do
          string = "_patchinfo:#{sized(1) { string(/[a-zA-Z0-9]/) }}#{sized(range(0, 188)) { string(/[-+\w.]/) }}"
          guard(string != '0')
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

  describe '#buildresult' do
    it 'returns an object with class LocalBuildResult::ForPackage' do
      expect(package.buildresult(home_project).class).to eq(LocalBuildResult::ForPackage)
    end
  end

  describe '#source_path' do
    it { expect(package_with_file.source_path).to eq('/source/home:tom/package_with_files') }
    it { expect(package_with_file.source_path('icon')).to eq('/source/home:tom/package_with_files/icon') }
    it { expect(package_with_file.source_path('icon', format: :html)).to eq('/source/home:tom/package_with_files/icon?format=html') }
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
        expect(result).to eq(%w[gcc6 xz])
      end
    end

    context 'with invalid repository or architecture' do
      before do
        allow(Backend::Connection).to receive(:get).and_raise(Backend::NotFoundError.new('message'))
      end

      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end
  end

  describe '.jobhistory' do
    subject { package.jobhistory(repository_name: 'openSUSE_Tumbleweed', arch_name: 'x86_64') }

    let(:backend_url) { "#{CONFIG['source_url']}/build/#{home_project}/openSUSE_Tumbleweed/x86_64/_jobhistory?limit=100&package=#{package}" }
    let(:backend_response) { file_fixture('jobhistory.xml') }

    context 'when response is successful' do
      let(:local_job_history) do
        { revision: '1',
          srcmd5: '2ac8bd685591b40e412ee99b182f94c2',
          build_counter: '1',
          worker_id: 'vagrant-openSUSE-Leap:1',
          host_arch: 'x86_64',
          reason: 'new build',
          ready_time: 1_492_687_344,
          start_time: 1_492_687_470,
          end_time: 1_492_687_507,
          total_time: 37,
          code: 'succeed' }
      end

      before do
        stub_request(:get, backend_url).and_return(body: backend_response)
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
      before { stub_request(:get, backend_url).and_raise(Backend::NotFoundError) }

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
    let(:result) { package.last_build_reason('openSUSE_Leap_42.3', 'x86_64') }
    let(:time) { 1_496_387_771 }

    before do
      stub_request(:get, path).and_return(body:
        %(<reason>\n  <explain>source change</explain>  <time>#{time}</time>  <oldsource>1de56fdc419ea4282e35bd388285d370</oldsource></reason>))
    end

    it 'returns a PackageBuildReason object' do
      expect(result).to be_a(PackageBuildReason)
    end

    context 'validation of data' do
      it 'for: explain' do
        expect(result.explain).to eq('source change')
      end

      it 'for: time' do
        expect(result.time).to eq(Time.at(time))
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
              'key' => 'libsystemd0-mini'
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
              'key' => 'libsystemd0-mini'
            },
            {
              'change' => 'md5sum',
              'key' => 'python3-websockets'
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
    subject { package.sources_changed }

    let!(:project) { create(:project, name: 'apache') }
    let!(:package) { create(:package_with_file, name: 'mod_ssl', project: project) }

    it 'creates a BackendPackge for the Package' do
      expect { subject }.to change(BackendPackage, :count).by(1)
    end
  end

  describe '#commit_message_from_changes_file' do
    let(:changes_file) { file_fixture('factory_target_package.changes').read }
    let(:project) { create(:project, name: 'home:foo:Apache') }
    let(:package) { create(:package_with_changes_file, project: project, name: 'package_with_changes_file') }

    context 'with a diff to the target package changes file' do
      subject { package.commit_message_from_changes_file(target_project, target_package) }

      let(:target_project)  { create(:project, name: 'Apache') }
      let!(:target_package) do
        create(:package_with_changes_file, project: target_project, name: 'package_with_changes_file', changes_file_content: changes_file)
      end

      it { expect(subject).to include('- Testing the submit diff') }
      it { expect(subject).not_to include('- Temporary hack') }
      it { expect(subject).not_to include('Fri Aug 11 16:58:15 UTC 2017 - tom@opensuse.org') }
      it { expect(subject).not_to include('Wed Aug  2 14:59:15 UTC 2017 - iggy@opensuse.org') }
      it { expect(subject).not_to include('-------------------------------------------------------------------') }
    end

    context 'with no diff to the target package changes file' do
      subject { package.commit_message_from_changes_file(nil, nil) }

      it { expect(subject).to include('- Testing the submit diff') }
      it { expect(subject).to include('- Temporary hack') }
      it { expect(subject).not_to include('Fri Aug 11 16:58:15 UTC 2017 - tom@opensuse.org') }
      it { expect(subject).not_to include('Wed Aug  2 14:59:15 UTC 2017 - iggy@opensuse.org') }
      it { expect(subject).not_to include('-------------------------------------------------------------------') }
    end

    context 'of a package without a changes file' do
      let(:package) { create(:package, project: project, name: 'apache2') }

      it { expect(package.commit_message_from_changes_file(nil, nil)).to eq('') }
    end

    context 'of a package with more than one changes file' do
      before do
        if CONFIG['global_write_through']
          full_path = "/source/#{package.project.name}/#{package.name}/lorem.changes"
          Backend::Connection.put(Addressable::URI.escape(full_path), 'Lorem ipsum dolorem')
        end
      end

      it { expect(package.commit_message_from_changes_file(nil, nil)).to include('Lorem ipsum dolorem') }
    end
  end

  describe '#add_maintainer' do
    subject { package }

    it_behaves_like 'makes a user a maintainer of the subject'
  end

  describe '#release_target_name' do
    it "returns the package name for 'normal' projects" do
      expect(package.release_target_name).to eq(package.name)
    end

    context 'when package belongs to a maintenance incident' do
      let(:maintenance_incident_project) { create(:maintenance_incident_project, name: 'hello_world_project') }
      let(:package) { create(:package, name: 'hello_world', project: maintenance_incident_project) }

      it 'adds the project basename as suffix' do
        expect(package.release_target_name).to eq("#{package.name}.#{package.project.basename}")
      end
    end
  end

  describe '.exists_by_project_and_name' do
    subject { package.name }

    let(:project_name) { package.project.name }

    context 'for local package' do
      it 'returns true for an existing package' do
        expect(Package.exists_by_project_and_name(project_name, subject)).to be_truthy
      end

      it 'returns false for a not existing package' do
        expect(Package.exists_by_project_and_name(project_name, 'does-not-exist:hello-world')).to be_falsey
      end

      it 'returns false for a not existing project' do
        expect(Package.exists_by_project_and_name('does-not-exist', subject)).to be_falsey
      end
    end

    context 'for multibuild package' do
      it 'returns true for an existing local package' do
        expect(Package.exists_by_project_and_name(project_name, subject, follow_multibuild: true)).to be_truthy
      end

      it 'returns true for an existing multibuild package' do
        expect(Package.exists_by_project_and_name(project_name, "#{subject}:hello-world", follow_multibuild: true)).to be_truthy
      end

      it 'returns false for a not existing multibuild package' do
        expect(Package.exists_by_project_and_name(project_name, 'does-not-exist:hello-world', follow_multibuild: true)).to be_falsey
      end

      it 'returns false for an existing multibuild package without follow_multibuild option' do
        expect(Package.exists_by_project_and_name(project_name, "#{subject}:hello-world")).to be_falsey
      end
    end
  end

  describe '#ignored_requests' do
    let(:project) { create(:project, name: 'my_project') }

    context "when the package has an 'ignored_requests' file" do
      let(:package) do
        create(:package_with_file, project: project, name: 'dashboard_1', file_name: 'ignored_requests', file_content: 'foo: bar')
      end

      it 'parses the content as YAML and returns a hash' do
        expect(package.ignored_requests).to eq('foo' => 'bar')
      end
    end

    context "when the package has no 'ignored_requests' file" do
      let(:package) { create(:package, project: project, name: 'dashboard_2') }

      it { expect(package.ignored_requests).to be_nil }
    end
  end

  describe '#belongs_to_product?' do
    context 'a product package (_product)' do
      subject { create(:package, name: '_product') }

      it { expect(subject.belongs_to_product?).to be false }
    end

    context 'a product sub package (_product:*)' do
      subject { create(:package, name: '_product:foo', project: project) }

      let(:project) { create(:project) }

      context 'that was generated by a _product file' do
        let!(:product_package) { create(:package, name: '_product', project: project) }

        it { expect(subject.belongs_to_product?).to be true }
      end

      context 'that was not auto-generated' do
        it { expect(subject.belongs_to_product?).to be false }
      end
    end
  end

  describe '#update_from_xml' do
    let(:invalid_meta_xml) do
      <<-XML_DATA
      <package>
        <title/>
        <description/>
        <build>
          <enable/>
          <disable/>
          <enable arch="i586"/>
          <disable arch="x86_64"/>
          <enable arch="x86_64"/>
        </build>
      </package>
      XML_DATA
    end
    let(:corrected_meta_xml) do
      <<~XML_DATA2
        <package name="test_package" project="home:tom">
          <title/>
          <description/>
          <build>
            <disable/>
            <enable arch="i586"/>
            <disable arch="x86_64"/>
          </build>
        </package>
      XML_DATA2
    end

    it "doesn't crash on duplicated flags" do
      package.update_from_xml(Xmlhash.parse(invalid_meta_xml))
      expect(package.render_xml).to eq(corrected_meta_xml)
    end
  end

  describe '#add_containers' do
    let(:maintenance_update_with_package) { create(:maintenance_project, name: 'project_foo') }
    let(:first_maintained_package) { create(:package_with_file, name: 'package_bar', project: maintenance_update_with_package) }

    it { expect { first_maintained_package.add_containers({}) }.not_to raise_error }
  end

  describe '#resolve_devel_package' do
    subject { stable_apache.resolve_devel_package }

    let!(:stable_project) { create(:project, name: 'stable_project') }
    let!(:stable_apache) { create(:package, name: 'apache', project: stable_project) }

    let!(:unstable_project) { create(:project, name: 'unstable_project') }
    let!(:unstable_apache) { create(:package, name: 'apache', project: unstable_project) }

    context 'with develproject' do
      before do
        stable_project.develproject = unstable_project
      end

      it { expect(subject).to eq(unstable_apache) }
    end

    context 'with develpackage' do
      before do
        stable_apache.develpackage = unstable_apache
      end

      it { expect(subject).to eq(unstable_apache) }
    end

    context 'with cycle' do
      before do
        stable_apache.develpackage = unstable_apache
        unstable_apache.develpackage = stable_apache
      end

      it { expect { subject }.to raise_error(Package::CycleError) }
    end
  end

  describe '#report_bug_url' do
    before do
      # Locally the configuration returns https://unconfigured.openbuildservice.org
      # as host so we use a better host
      allow(Configuration).to receive(:obs_url).and_return('https://localhost:3000')
      package.valid?
    end

    context 'url is external' do
      let(:package) { build(:package, report_bug_url: 'https://example.com') }

      it { expect(package.errors).to be_empty }
    end

    context 'url is relative' do
      let(:package) { build(:package, report_bug_url: '/about') }

      it { expect(package.errors[:report_bug_url]).to eql(['Local urls are not allowed']) }
    end

    context 'url has no protocol' do
      let(:package) { build(:package, report_bug_url: 'example.com') }

      it { expect(package.errors).to be_empty }
    end

    context 'local url has no protocol' do
      let(:package) { build(:package, report_bug_url: 'localhost:3000/about') }

      it { expect(package.errors[:report_bug_url]).to eql(['Local urls are not allowed']) }
    end
  end

  describe '#bs_requests' do
    let(:package) { create(:package) }
    let!(:incoming_request) { create(:bs_request_with_submit_action, target_package: package) }
    let!(:outgoing_request) { create(:bs_request_with_submit_action, source_package: package) }
    let!(:request_with_review) { create(:delete_bs_request, target_project: create(:project), review_by_package: package) }
    let!(:unrelated_request) { create(:bs_request_with_submit_action, target_package: create(:package)) }

    it { expect(package.bs_requests).to contain_exactly(incoming_request, outgoing_request, request_with_review) }
  end
end
