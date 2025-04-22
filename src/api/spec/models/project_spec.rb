require 'rantly/rspec_extensions'

RSpec.describe Project, :vcr do
  let!(:project) { create(:project, name: 'openSUSE_41') }
  let(:remote_project) { create(:remote_project, name: 'openSUSE.org') }
  let(:package) { create(:package, project: project) }
  let(:leap_project) { create(:project, name: 'openSUSE_Leap') }
  let(:attribute_type) { AttribType.find_by_namespace_and_name!('OBS', 'ImageTemplates') }
  let(:user) { create(:confirmed_user) }

  describe 'validations' do
    it {
      expect(subject).to validate_inclusion_of(:kind)
        .in_array(%w[standard maintenance maintenance_incident maintenance_release])
    }

    it { is_expected.to validate_length_of(:name).is_at_most(200) }
    it { is_expected.to validate_length_of(:title).is_at_most(250) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.not_to allow_value('0').for(:name) }
    it { is_expected.not_to allow_value('foo::bar').for(:name) }
    it { is_expected.not_to allow_value('foo:_bar').for(:name) }
    it { is_expected.not_to allow_value('foo:.bar').for(:name) }
    it { is_expected.not_to allow_value(':foo').for(:name) }
    it { is_expected.not_to allow_value('_foo').for(:name) }
    it { is_expected.not_to allow_value('.foo').for(:name) }
    it { is_expected.not_to allow_value('ends_with_:').for(:name) }
    it { is_expected.to allow_value('fOO:123:+-_.').for(:name) }
  end

  describe '.image_templates' do
    let(:attrib) { create(:attrib, attrib_type: attribute_type, project: leap_project) }

    it 'has leap template' do
      login user
      attrib
      expect(Project.image_templates).to eq([leap_project])
    end
  end

  describe '#store' do
    before do
      allow(project).to receive_messages(save!: true, write_to_backend: true)
      project.commit_opts = { comment: 'the comment' }
    end

    context 'without commit_opts parameter' do
      it 'does not overwrite the commit_opts' do
        project.store
        expect(project.commit_opts).to eq(comment: 'the comment')
      end
    end

    context 'with commit_opts parameter' do
      it 'does overwrite the commit_opts' do
        project.store(comment: 'a new comment')
        expect(project.commit_opts).to eq(comment: 'a new comment')
      end
    end
  end

  describe '#distribution?' do
    context 'remote distribution' do
      let(:remote_distribution) { create(:repository, name: 'snapshot', remote_project_name: 'openSUSE:Factory', project: remote_project) }
      let(:other_remote_distribution) { create(:repository, name: 'standard', remote_project_name: 'openSUSE:Leap:42.1', project: remote_project) }
      let(:repository) { create(:repository, name: 'openSUSE_Tumbleweed', project: project) }
      let!(:path_element) { create(:path_element, parent_id: repository.id, repository_id: remote_distribution.id, position: 1) }

      it { expect(project.distribution?('openSUSE.org:openSUSE:Factory', 'snapshot')).to be(true) }
      it { expect(project.distribution?('openSUSE.org:openSUSE:Leap:42.1', 'standard')).to be(false) }
    end

    context 'local distribution' do
      context 'with linked distribution' do
        let(:distribution) { create(:project, name: 'BaseDistro2.0') }
        let(:distribution_repository) { create(:repository, name: 'BaseDistro2_repo', project: distribution) }
        let(:repository) { create(:repository, name: 'Base_repo2', project: project) }
        let!(:path_element) { create(:path_element, parent_id: repository.id, repository_id: distribution_repository.id, position: 1) }

        it { expect(project.distribution?('BaseDistro2.0', 'BaseDistro2_repo')).to be(true) }
      end

      context 'with not linked distribution' do
        let(:not_linked_distribution) { create(:project, name: 'BaseDistro') }
        let!(:not_linked_distribution_repository) { create(:repository, name: 'BaseDistro_repo', project: not_linked_distribution) }

        it { expect(project.distribution?('BaseDistro', 'BaseDistro_repo')).to be(false) }
      end

      context 'with linked distribution but wrong query' do
        let(:other_distribution) { create(:project, name: 'BaseDistro3.0') }
        let!(:other_distribution_repository) { create(:repository, name: 'BaseDistro3_repo', project: other_distribution) }
        let(:other_repository) { create(:repository, name: 'Base_repo3', project: project) }
        let!(:path_element) { create(:path_element, parent_id: other_repository.id, repository_id: other_distribution_repository.id, position: 1) }

        it { expect(project.distribution?('BaseDistro3.0', 'standard')).to be(false) }
        it { expect(project.distribution?('BaseDistro4.0', 'BaseDistro3_repo')).to be(false) }
      end
    end
  end

  describe '#image_template?' do
    let(:image_templates_attrib) { create(:attrib, attrib_type: attribute_type, project: leap_project) }
    let(:tumbleweed_project) { create(:project, name: 'openSUSE_Tumbleweed') }

    before do
      login user
      image_templates_attrib
    end

    it { expect(leap_project.image_template?).to be(true) }
    it { expect(tumbleweed_project.image_template?).to be(false) }
  end

  describe '#branch_remote_repositories' do
    let(:branch_remote_repositories) { project.branch_remote_repositories("#{remote_project}:#{project}") }

    before do
      logout
      meta_project_file_mock = double('meta', content: remote_meta_xml)
      allow(ProjectMetaFile).to receive(:new).and_return(meta_project_file_mock)
    end

    context 'normal project' do
      let!(:repository) { create(:repository, name: 'xUbuntu_14.04', project: project) }
      let(:remote_meta_xml) do
        <<-XML_DATA
          <project name="home:mschnitzer">
            <title>Cool Title</title>
            <description>Cool Description</description>
            <repository name="xUbuntu_14.04">
              <path project="Ubuntu:14.04" repository="universe"/>
              <arch>i586</arch>
              <arch>x86_64</arch>
            </repository>
            <repository name="openSUSE_42.2">
              <path project="openSUSE:Leap:42.2:Update" repository="standard"/>
              <path project="openSUSE:Leap:42.2:Update2" repository="standard"/>
              <arch>x86_64</arch>
            </repository>
          </project>
        XML_DATA
      end
      let(:expected_xml_meta) do
        <<-XML_DATA
          <project name="#{project}">
            <title>#{project.title}</title>
            <description/>
            <repository name="xUbuntu_14.04">
            </repository>
            <repository name="openSUSE_42.2">
              <path project="#{remote_project.name}:#{project}" repository="openSUSE_42.2"/>
              <arch>x86_64</arch>
            </repository>
          </project>
        XML_DATA
      end

      before do
        branch_remote_repositories
        project.reload
      end

      it 'has proper project xml' do
        expect(Xmlhash.parse(project.render_xml)).to eq(Xmlhash.parse(expected_xml_meta))
      end

      context 'keeps original repository' do
        let(:old_repository) { project.repositories.first }

        it { expect(old_repository).to eq(repository) }
        it { expect(old_repository.architectures).to be_empty }
        it { expect(old_repository.path_elements).to be_empty }
      end

      context 'adds new reposity' do
        let(:new_repository) { project.repositories.second }
        let(:path_element) { new_repository.path_elements.first.link }

        it { expect(new_repository.name).to eq('openSUSE_42.2') }
        it { expect(new_repository.architectures.first.name).to eq('x86_64') }

        it 'with correct path link' do
          expect(path_element.name).to eq('openSUSE_42.2')
          expect(path_element.remote_project_name).to eq(project.name)
        end
      end
    end

    context 'kiwi project' do
      let(:remote_meta_xml) do
        <<-XML_DATA
        <project name="home:cbruckmayer:fosdem">
          <title>FOSDEM 2017</title>
          <description/>
          <repository name="openSUSE_Leap_42.1">
            <path project="openSUSE:Leap:42.1" repository="standard"/>
            <arch>x86_64</arch>
          </repository>
          <repository name="images">
            <path project="openSUSE.org:openSUSE:Leap:42.1:Images" repository="standard"/>
            <path project="openSUSE.org:openSUSE:Leap:42.1:Update" repository="standard"/>
            <arch>x86_64</arch>
          </repository>
        </project>
        XML_DATA
      end
      let(:path_elements2) { new_repository.path_elements.second.link }
      let(:path_elements) { new_repository.path_elements.first.link }
      let(:new_repository) { project.repositories.second }
      let(:expected_xml_meta) do
        <<-XML_DATA
        <project name="#{project}">
          <title>#{project.title}</title>
          <description/>
          <repository name="openSUSE_Leap_42.1">
            <path project="#{remote_project.name}:#{project}" repository="openSUSE_Leap_42.1"/>
            <arch>x86_64</arch>
          </repository>
          <repository name="images">
            <path project="openSUSE.org:openSUSE:Leap:42.1:Images" repository="standard"/>
            <path project="openSUSE.org:openSUSE:Leap:42.1:Update" repository="standard"/>
            <arch>x86_64</arch>
          </repository>
        </project>
        XML_DATA
      end

      before do
        branch_remote_repositories
        project.reload
      end

      it 'has proper project xml' do
        expect(Xmlhash.parse(project.render_xml)).to eq(Xmlhash.parse(expected_xml_meta))
      end

      it { expect(new_repository.name).to eq('images') }
      it { expect(new_repository.architectures.first.name).to eq('x86_64') }

      it 'with correct path links' do
        expect(new_repository.path_elements.count).to eq(2)
        expect(path_elements.name).to eq('standard')
        expect(path_elements.remote_project_name).to eq('openSUSE:Leap:42.1:Images')
        expect(path_elements2.name).to eq('standard')
        expect(path_elements2.remote_project_name).to eq('openSUSE:Leap:42.1:Update')
      end
    end
  end

  describe '#self.valid_name?' do
    context 'invalid' do
      it { expect(Project.valid_name?(10)).to be(false) }

      it 'has ::' do
        property_of do
          string = sized(1) { string(/[a-zA-Z0-9\-+]/) } + sized(range(1, 199)) { string(/[-+\w.:]/) }
          index = range(0, string.length - 2)
          string[index] = string[index + 1] = ':'
          string
        end.check do |string|
          expect(Project.valid_name?(string)).to be(false)
        end
      end

      it 'end with :' do
        property_of do
          string = "#{sized(1) { string(/[a-zA-Z0-9\-+]/) }}#{sized(range(0, 198)) { string(/[-+\w.:]/) }}:"
          guard(string !~ /:[:._]/)
          string
        end.check do |string|
          expect(Project.valid_name?(string)).to be(false)
        end
      end

      it 'has an invalid character in first position' do
        property_of do
          string = sized(1) { string(/[.:_]/) } + sized(range(0, 199)) { string(/[-+\w.:]/) }
          guard(!(string[-1] == ':' && string.length > 1) && string !~ /:[:._]/)
          string
        end.check do |string|
          expect(Project.valid_name?(string)).to be(false)
        end
      end

      it 'has more than 200 characters' do
        property_of do
          string = sized(1) { string(/[a-zA-Z0-9\-+]/) } + sized(200) { string(/[-+\w.:]/) }
          guard(string[-1] != ':' && string !~ /:[:._]/)
          string
        end.check(3) do |string|
          expect(Project.valid_name?(string)).to be(false)
        end
      end

      it { expect(Project.valid_name?('0')).to be(false) }
      it { expect(Project.valid_name?('')).to be(false) }
    end

    it 'valid' do
      property_of do
        string = sized(1) { string(/[a-zA-Z0-9\-+]/) } + sized(range(0, 199)) { string(/[-+\w.:]/) }
        guard(string != '0' && string[-1] != ':' && !(/:[:._]/ =~ string))
        string
      end.check do |string|
        expect(Project.valid_name?(string)).to be(true)
      end
    end
  end

  describe '#open_requests' do
    shared_examples 'with_open_requests' do
      subject { project.open_requests }

      let(:admin_user) { create(:admin_user, login: 'king') }
      let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
      let(:source_package) { create(:package, :as_submission_source) }

      let!(:review) do
        create(:bs_request_with_submit_action, creator: admin_user, target_project: project, source_package: source_package, review_by_user: confirmed_user)
      end

      let!(:target) { create(:bs_request_with_submit_action, creator: confirmed_user, source_package: source_package, target_project: project) }
      let!(:other_target) do
        create(:bs_request_with_submit_action, creator: admin_user, target_project: project, source_package: source_package)
      end
      let!(:declined_target) do
        create(:declined_bs_request, creator: confirmed_user, target_package: package, source_package: source_package)
      end

      let!(:incident) do
        create(:bs_request_with_maintenance_incident_actions, creator: admin_user, target_project: project, source_package: source_package)
      end
      let(:accepted_incident) do
        create(:bs_request_with_maintenance_incident_actions, creator: admin_user, target_package: package, source_package: source_package)
      end

      let!(:release) do
        create(:bs_request_with_maintenance_release_actions, creator: admin_user, target_package: package, source_package: source_package)
      end
      let!(:other_release) do
        create(:bs_request_with_maintenance_release_actions, creator: admin_user, target_package: package, source_package: source_package)
      end

      before do
        accepted_incident.state = :accepted
        accepted_incident.save!
      end

      it 'does include reviews' do
        expect(subject[:reviews]).to eq([review.number])
      end

      it 'does include targets' do
        expect(subject[:targets]).to eq([incident, other_target, target].pluck(:number))
      end

      it 'does include incidents' do
        expect(subject[:incidents]).to eq([incident.number])
      end
    end

    context 'without a maintenance project' do
      it_behaves_like 'with_open_requests' do
        let(:project) { create(:project, name: 'sandman') }
        let(:subproject) { create(:project, name: 'sandman:dreams') }
        let(:package) { create(:package, project: subproject) }

        it 'does not include maintenance_release' do
          expect(subject[:maintenance_release]).to eq([])
        end
      end
    end

    context 'with a maintenance project' do
      it_behaves_like 'with_open_requests' do
        let(:project) { create(:project, name: 'battlestar', kind: 'maintenance') }
        let(:subproject) { create(:project, name: 'battlestar:ebony') }
        let(:package) { create(:package, project: subproject) }

        it 'does include maintenance_release' do
          expect(subject[:maintenance_release]).to eq([other_release.number, release.number])
        end
      end
    end
  end

  describe '.deleted?' do
    it 'returns false if the project exists in the app' do
      expect(Project).not_to be_deleted(project.name)
    end

    it 'returns false if backend responds with nothing' do
      allow_any_instance_of(ProjectFile).to receive(:content).with(deleted: 1).and_return(nil)
      expect(Project).not_to be_deleted('never-existed-before')
    end

    it 'returns false if revision list element of _history file is empty' do
      allow_any_instance_of(ProjectFile).to receive(:content).with(deleted: 1).and_return("<revisionlist>\n</revisionlist>\n")
      expect(Project).not_to be_deleted('never-existed-before')
    end

    it 'returns true if _history element has elements' do
      allow_any_instance_of(ProjectFile).to receive(:content).with(deleted: 1).and_return(
        "<revisionlist>\n  <revision rev=\"1\" vrev=\"\">\n    <srcmd5>d41d8cd98f00b204e9800998ecf8427e</srcmd5>\n    " \
        "<version></version>\n    <time>1498113679</time>\n    <user>Admin</user>\n    <comment>1</comment>\n  " \
        "</revision>\n</revisionlist>\n"
      )

      expect(Project).to be_deleted('very-nice-project-name')
    end
  end

  describe '.restore' do
    let(:admin_user) { create(:admin_user, login: 'Admin') }
    let(:deleted_project) do
      create(:project_with_packages,
             name: 'project_used_for_restoration',
             title: 'restoration_project_title',
             package_title: 'restoration_title',
             package_description: 'restoration_desc',
             package_name: 'restoration_package')
    end

    # make sure it's gone even if some previous test failed
    def reset_project_in_backend
      Backend::Api::Sources::Project.delete 'project_used_for_restoration' if CONFIG['global_write_through']
    rescue Backend::NotFoundError
      # Ignore this exception on purpose
    end

    before do
      login(admin_user)
    end

    it 'sets the user that restored the project in the history element' do
      reset_project_in_backend
      deleted_project.destroy!
      Project.restore(deleted_project.name, user: admin_user.login)

      meta = Xmlhash.parse(ProjectFile.new(project_name: deleted_project.name, name: '_history').content(deleted: 1))
      expect(meta.elements('revision').last['user']).to eq(admin_user.login)
    end

    context 'with linked repositories' do
      let(:repository1) { create(:repository, name: 'Tumbleweed', architectures: %w[i586 x86_64], project: deleted_project) }
      let(:repository2) { create(:repository, name: 'RepoWithLink', architectures: %w[i586 x86_64], project: deleted_project) }
      let!(:path_elements) { create(:path_element, repository: repository2, link: repository1) }

      it 'project meta is properly restored' do
        reset_project_in_backend
        deleted_project.write_to_backend
        old_project_meta_xml = ProjectMetaFile.new(project_name: deleted_project.name).content
        deleted_project.destroy!

        restored_project = Project.restore(deleted_project.name, user: admin_user.login)
        expect(restored_project.meta.content).to eq(old_project_meta_xml)
      end
    end

    context 'on a project with packages' do
      subject { Project.restore('project_used_for_restoration', user: admin_user.login) }

      let(:package1) { deleted_project.packages.first }
      let(:package1_meta_before_deletion) { package1.render_xml }
      let(:package2) { deleted_project.packages.last }
      let(:package2_meta_before_deletion) { package2.render_xml }

      before do
        reset_project_in_backend
        deleted_project.destroy!
      end

      it 'creates package records in the database' do
        expect(subject.packages.size).to eq(2)
      end

      context 'verifies the meta of restored packages' do
        it { expect(subject.packages.find_by(name: package1.name).render_xml).to eq(package1_meta_before_deletion) }
        it { expect(subject.packages.find_by(name: package2.name).render_xml).to eq(package2_meta_before_deletion) }
      end
    end
  end

  describe '#destroy' do
    context 'avoid regressions of the issue #3665' do
      let(:admin_user) { create(:admin_user, login: 'Admin') }
      let(:images_repository) { create(:repository, name: 'images', project: project) }
      let(:apache_repository) { create(:repository, name: 'Apache', project: project) }
      let!(:path_element) { create(:path_element, parent_id: images_repository.id, repository_id: apache_repository.id, position: 1) }

      before do
        login admin_user
        project.destroy!
      end

      it { expect(Project).to be_deleted(project.name) }
    end
  end

  describe '#render_relationships' do
    let!(:project) { create(:project) }
    let!(:group) { create(:group) }
    let!(:user) { create(:user) }
    let!(:role) { Role.find_by_title('bugowner') }
    let!(:relationship1) do
      create(:relationship_project_group, project: project, group: group, role: role)
    end
    let!(:relationship2) do
      create(:relationship_project_user, project: project, user: user, role: role)
    end
    let(:xml) { double }

    before do
      allow(xml).to receive(:person)
      allow(xml).to receive(:group)

      project.render_relationships(xml)
    end

    it { expect(xml).to have_received(:person).with(userid: user.login, role: 'bugowner') }
    it { expect(xml).to have_received(:group).with(groupid: group.title, role: 'bugowner') }
  end

  # NOTE: the code deletes a user with user.delete (not user.destroy) which has a customized behaviour, setting the user to `state=delete`.
  describe '#maintainers' do
    subject { user1.home_project }

    let(:user1) { create(:confirmed_user, :with_home) }
    let(:user2) { create(:confirmed_user) }
    let(:group_user) { create(:confirmed_user) }
    let(:group) { create(:group_with_user, user: group_user) }
    let!(:user_relationship) { create(:relationship_project_user, project: subject, user: user2) }
    let!(:group_relationship) { create(:relationship_project_group, project: subject, group: group) }

    before { group.users << user2 }

    it 'returns all the users but user_2 only once' do
      expect(subject.maintainers).to match([user1, user2, group_user])
    end

    context 'when one of the users is deleted' do
      before { user2.delete }

      it 'still returns the deleted user' do
        expect(subject.maintainers).to match([user1, user2, group_user])
      end
    end

    context 'when the group is deleted' do
      before do
        group.destroy
      end

      it "returns the deleted user but not the deleted group's user" do
        expect(subject.maintainers).to match([user1, user2])
      end
    end
  end

  describe '#remove_all_persons' do
    let!(:project) { create(:project) }
    let!(:user) { create(:user) }
    let!(:relationship) do
      create(:relationship, project: project, user: user)
    end

    before do
      login(user)

      project.remove_all_persons
    end

    it 'deletes the relationship' do
      expect(Relationship).not_to exist(relationship.id)
    end
  end

  describe '#remove_all_groups' do
    let!(:project) { create(:project) }
    let!(:group) { create(:group) }
    let!(:groups_user) { create(:groups_user, group: group) }
    let!(:relationship) do
      create(:relationship, project: project, group: group)
    end

    before do
      login(groups_user.user)

      project.remove_all_groups
    end

    it 'deletes the relationship' do
      expect(Relationship).not_to exist(relationship.id)
    end
  end

  describe '#add_maintainer' do
    subject { create(:user, :with_home).home_project }

    it_behaves_like 'makes a user a maintainer of the subject'
  end

  describe '#basename' do
    subject { create(:project, name: 'foo:bar:baz') }

    it "returns the lowest level of ':' separated subproject names" do
      expect(subject.basename).to eq('baz')
    end
  end

  describe '#do_project_release' do
    let(:user) { create(:confirmed_user, :with_home, login: 'tux') }
    let(:project) { user.home_project }
    let!(:package) { create(:package_with_revisions, name: 'my_package_release', project: project) }
    let(:project_release) { create(:project, name: "#{user.home_project}:staging") }
    let(:repository) { create(:repository, project: project) }
    let(:repository_release) { create(:repository, project: project_release) }
    let!(:release_target) { create(:release_target, target_repository: repository_release, repository: repository, trigger: 'manual') }

    before do
      login user
      allow_any_instance_of(Package).to receive(:release_target_name).and_return('my_release_target')
    end

    it "uses the package's release target name when releasing the package" do
      project.do_project_release(user: user.login)
      expect(project_release.packages.where(name: 'my_release_target')).to exist
    end
  end

  describe '#update_from_xml' do
    let(:project) { create(:project) }
    let(:invalid_meta_xml) do
      <<-XML_DATA
      <project name="#{project.name}">
        <title>Mine</title>
        <description/>
        <build>
          <enable/>
          <disable/>
          <enable arch="i586"/>
          <disable arch="x86_64"/>
          <disable/>
          <enable/>
          <enable arch="x86_64"/>
        </build>
      </project>
      XML_DATA
    end

    let(:new_xml) do
      project.update_from_xml!(Xmlhash.parse(invalid_meta_xml))
      project.save!
      Xmlhash.parse(project.render_xml)
    end

    it 'ignores duplicated flags' do
      expect(new_xml['build']['disable']).to contain_exactly({}, 'arch' => 'x86_64')
    end

    it 'erases all enable flags shadowed' do
      expect(new_xml['build']['enable']).to eq({ 'arch' => 'i586' })
    end

    it 'updates basics' do
      expect(new_xml).to include('title' => 'Mine', 'description' => {}, 'name' => project.name)
    end
  end

  describe '#categories' do
    subject do
      project.categories
    end

    let(:project) { create(:project) }
    let(:attrib_namespace) { AttribNamespace.create!(name: 'OBS') }

    context 'when there are quality categories attributes set for the project' do
      let(:category_attrib_type) do
        AttribType.create!(name: 'QualityCategory',
                           attrib_namespace: attrib_namespace)
      end
      let(:attrib) do
        Attrib.create!(attrib_type: category_attrib_type,
                       project: project)
      end

      before do
        AttribValue.create!(attrib: attrib, value: 'Test')
        AttribValue.create!(attrib: attrib, value: 'Private')
      end

      it 'returns the categories values' do
        expect(subject).to eql(%w[Test Private])
      end
    end

    context 'when there are no quality categories attributes set for the project' do
      it 'returns no values' do
        expect(subject).to be_empty
      end
    end
  end

  describe '#very_important_projects_with_categories' do
    subject do
      Project.very_important_projects_with_categories
    end

    let(:project) { create(:project) }
    let(:attrib_namespace) { AttribNamespace.create!(name: 'OBS') }

    context 'when there are Very Important Projects' do
      context 'with quality categories' do
        let(:vip_attrib_type) do
          AttribType.create!(name: 'VeryImportantProject',
                             attrib_namespace: attrib_namespace)
        end
        let!(:category_attrib_type) do
          AttribType.create!(name: 'QualityCategory',
                             attrib_namespace: attrib_namespace)
        end
        let!(:attrib) do
          Attrib.create!(attrib_type: vip_attrib_type,
                         project: project)
          Attrib.create!(attrib_type: category_attrib_type,
                         project: project)
        end
        let!(:attrib_value) do
          AttribValue.create!(attrib: attrib,
                              value: 'Test')
        end

        it "returns the project's name, title and categories" do
          expect(subject).to eql([[project.name, project.title, ['Test']]])
        end
      end

      context 'with no quality categories' do
        let(:vip_attrib_type) do
          AttribType.create!(name: 'VeryImportantProject',
                             attrib_namespace: attrib_namespace)
        end
        let!(:attrib) do
          Attrib.create!(attrib_type: vip_attrib_type,
                         project: project)
        end

        it "returns the project's name, title but no categories" do
          expect(subject).to eql([[project.name, project.title, []]])
        end
      end
    end

    context 'when there are no Very Important Projects' do
      it 'returns an empty collection' do
        expect(subject).to eql([])
      end
    end
  end

  describe '#expand_maintained_projects' do
    subject { maintenance_project.expand_maintained_projects }

    let(:link_target_project) { create(:project, name: 'openSUSE:Maintenance') }
    let(:maintenance_project) { create(:maintenance_project, target_project: link_target_project) }

    it { expect(subject).not_to be_empty }
    it { expect(subject).to include(link_target_project) }
  end

  describe '#expand_all_repositories' do
    subject { project.expand_all_repositories }

    let!(:project) { create(:project_with_repository, name: 'super_project') }

    it { expect(subject).not_to be_empty }
    it { expect(subject).to include(project.repositories.first) }
  end

  describe '#project_state' do
    let(:project) { create(:project) }
    let(:fake_build_results) do
      <<-HEREDOC
      <resultlist state="768243617133224cac12a6c866b41d70">
        <result project="security:tools" repository="openSUSE_Leap_42.3" arch="x86_64" code="published" state="published">
          <status package="capstone" code="succeeded"/>
          <status package="docker-bench-security" code="succeeded"/>
          <status package="garmr" code="succeeded"/>
          <status package="hydra" code="succeeded"/>
          <status package="owasp-zap" code="succeeded"/>
        </result>
      </resultlist>
      HEREDOC
    end

    before do
      allow(Backend::Api::BuildResults::Status).to receive(:version_releases).and_return(fake_build_results)
    end

    it { expect(project.project_state).not_to be_nil }
  end

  describe '#find_remote_project' do
    let(:project) { create(:remote_project, name: 'hans:wurst') }

    it { expect(Project.find_remote_project(nil)).to be_nil }
    it { expect(Project.find_remote_project('peter:paul')).to be_nil }
    it { expect(Project.find_remote_project('hans:wurst')).to be_nil }
    it { expect(Project.find_remote_project('hans:wurst:leber')).to eq([project, 'leber']) }
    it { expect(Project.find_remote_project('hans:wurst:leber:salami')).to eq([project, 'leber:salami']) }
  end

  describe '#bs_requests' do
    let(:project) { create(:project) }
    let!(:incoming_request) { create(:bs_request_with_submit_action, source_project: project) }
    let!(:outgoing_request) { create(:bs_request_with_submit_action, target_project: project) }
    let!(:request_with_review) { create(:delete_bs_request, target_project: create(:project), review_by_project: project) }
    let!(:unrelated_request) { create(:bs_request_with_submit_action, source_project: create(:project)) }

    it { expect(project.bs_requests).to contain_exactly(incoming_request, outgoing_request, request_with_review) }
  end
end
