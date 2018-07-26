require 'rails_helper'
require 'rantly/rspec_extensions'
# WARNING: If you need to make a Backend call uncomment the following line
# CONFIG['global_write_through'] = true

RSpec.describe Project, vcr: true do
  let!(:project) { create(:project, name: 'openSUSE_41') }
  let(:remote_project) { create(:remote_project, name: 'openSUSE.org') }
  let(:package) { create(:package, project: project) }
  let(:leap_project) { create(:project, name: 'openSUSE_Leap') }
  let(:attribute_type) { AttribType.find_by_namespace_and_name!('OBS', 'ImageTemplates') }
  let(:user) { create(:confirmed_user) }

  describe 'validations' do
    it {
      is_expected.to validate_inclusion_of(:kind).
        in_array(['standard', 'maintenance', 'maintenance_incident', 'maintenance_release'])
    }
    it { is_expected.to validate_length_of(:name).is_at_most(200) }
    it { is_expected.to validate_length_of(:title).is_at_most(250) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { should_not allow_value('_foo').for(:name) }
    it { should_not allow_value('foo::bar').for(:name) }
    it { should_not allow_value('ends_with_:').for(:name) }
    it { should allow_value('fOO:+-').for(:name) }
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
      allow(project).to receive(:save!).and_return(true)
      allow(project).to receive(:write_to_backend).and_return(true)
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

  describe '#has_distribution' do
    context 'remote distribution' do
      let(:remote_distribution) { create(:repository, name: 'snapshot', remote_project_name: 'openSUSE:Factory', project: remote_project) }
      let(:other_remote_distribution) { create(:repository, name: 'standard', remote_project_name: 'openSUSE:Leap:42.1', project: remote_project) }
      let(:repository) { create(:repository, name: 'openSUSE_Tumbleweed', project: project) }
      let!(:path_element) { create(:path_element, parent_id: repository.id, repository_id: remote_distribution.id, position: 1) }

      it { expect(project.has_distribution('openSUSE.org:openSUSE:Factory', 'snapshot')).to be(true) }
      it { expect(project.has_distribution('openSUSE.org:openSUSE:Leap:42.1', 'standard')).to be(false) }
    end

    context 'local distribution' do
      context 'with linked distribution' do
        let(:distribution) { create(:project, name: 'BaseDistro2.0') }
        let(:distribution_repository) { create(:repository, name: 'BaseDistro2_repo', project: distribution) }
        let(:repository) { create(:repository, name: 'Base_repo2', project: project) }
        let!(:path_element) { create(:path_element, parent_id: repository.id, repository_id: distribution_repository.id, position: 1) }

        it { expect(project.has_distribution('BaseDistro2.0', 'BaseDistro2_repo')).to be(true) }
      end

      context 'with not linked distribution' do
        let(:not_linked_distribution) { create(:project, name: 'BaseDistro') }
        let!(:not_linked_distribution_repository) { create(:repository, name: 'BaseDistro_repo', project: not_linked_distribution) }

        it { expect(project.has_distribution('BaseDistro', 'BaseDistro_repo')).to be(false) }
      end

      context 'with linked distribution but wrong query' do
        let(:other_distribution) { create(:project, name: 'BaseDistro3.0') }
        let!(:other_distribution_repository) { create(:repository, name: 'BaseDistro3_repo', project: other_distribution) }
        let(:other_repository) { create(:repository, name: 'Base_repo3', project: project) }
        let!(:path_element) { create(:path_element, parent_id: other_repository.id, repository_id: other_distribution_repository.id, position: 1) }
        it { expect(project.has_distribution('BaseDistro3.0', 'standard')).to be(false) }
        it { expect(project.has_distribution('BaseDistro4.0', 'BaseDistro3_repo')).to be(false) }
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

      let(:path_elements2) { new_repository.path_elements.second.link }
      let(:path_elements) { new_repository.path_elements.first.link }
      let(:new_repository) { project.repositories.second }
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
          string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(1, 199)) { string(/[-+\w\.]/) }
          index = range(0, (string.length - 2))
          string[index] = string[index + 1] = ':'
          string
        end.check do |string|
          expect(Project.valid_name?(string)).to be(false)
        end
      end

      it 'end with :' do
        property_of do
          string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 198)) { string(/[-+\w\.:]/) } + ':'
          guard string !~ /::/
          string
        end.check do |string|
          expect(Project.valid_name?(string)).to be(false)
        end
      end

      it 'has an invalid character in first position' do
        property_of do
          string = sized(1) { string(/[-+\.:_]/) } + sized(range(0, 199)) { string(/[-+\w\.:]/) }
          guard !(string[-1] == ':' && string.length > 1) && string !~ /::/
          string
        end.check do |string|
          expect(Project.valid_name?(string)).to be(false)
        end
      end

      it 'has more than 200 characters' do
        property_of do
          string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(200) { string(/[-+\w\.:]/) }
          guard string[-1] != ':' && string !~ /::/
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
        string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 199)) { string(/[-+\w\.:]/) }
        guard string != '0' && string[-1] != ':' && !(/::/ =~ string)
        string
      end.check do |string|
        expect(Project.valid_name?(string)).to be(true)
      end
    end
  end

  describe '#open_requests' do
    shared_examples 'with_open_requests' do
      let(:admin_user) { create(:admin_user, login: 'king') }
      let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
      let(:other_project) { create(:project) }
      let(:package) { create(:package) }
      let(:other_package) { create(:package) }

      let!(:review) do
        create(:review_bs_request, creator: admin_user.login, target_project: project.name, source_project: other_project.name,
               target_package: package.name, source_package: other_package.name, reviewer: confirmed_user)
      end

      let!(:target) { create(:bs_request, creator: confirmed_user.login, source_project: project.name) }
      let!(:other_target) do
        create(:bs_request_with_submit_action, creator: admin_user.login, target_project: project.name, source_project: other_project.name,
                                                                          target_package: package.name, source_package: other_package.name)
      end
      let!(:declined_target) do
        create(:declined_bs_request, creator: confirmed_user.login, target_project: other_project.name, source_project: project.name,
                                                                          target_package: package.name, source_package: other_package.name)
      end

      let!(:incident) do
        create(:bs_request_with_maintenance_incident_action, creator: admin_user.login, target_project: project.name,
               source_project: subproject.name, target_package: other_package, source_package: package.name)
      end
      let(:accepted_incident) do
        create(:bs_request_with_maintenance_incident_action, creator: admin_user.login, target_project: project.name,
               source_project: subproject.name, target_package: other_package, source_package: package.name)
      end

      let!(:release) do
        create(:bs_request_with_maintenance_release_action, creator: admin_user.login, target_project: other_project.name,
               source_project: subproject.name, target_package: other_package, source_package: package.name)
      end
      let!(:other_release) do
        create(:bs_request_with_maintenance_release_action, creator: admin_user.login, target_project: subproject.name,
               source_project: other_project.name, target_package: package.name, source_package: other_package.name)
      end

      before do
        accepted_incident.state = :accepted
        accepted_incident.save!
      end

      subject { project.open_requests }

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

        it 'does not include maintenance_release' do
          expect(subject[:maintenance_release]).to eq([])
        end
      end
    end

    context 'with a maintenance project' do
      it_behaves_like 'with_open_requests' do
        let(:project) { create(:project, name: 'battlestar', kind: 'maintenance') }
        let(:subproject) { create(:project, name: 'battlestar:ebony') }

        it 'does include maintenance_release' do
          expect(subject[:maintenance_release]).to eq([other_release.number, release.number])
        end
      end
    end
  end

  describe '.deleted?' do
    it 'returns false if the project exists in the app' do
      expect(Project.deleted?(project.name)).to be_falsey
    end

    it 'returns false if backend responds with nothing' do
      allow_any_instance_of(ProjectFile).to receive(:content).with(deleted: 1).and_return(nil)
      expect(Project.deleted?('never-existed-before')).to be_falsey
    end

    it 'returns false if revision list element of _history file is empty' do
      allow_any_instance_of(ProjectFile).to receive(:content).with(deleted: 1).and_return("<revisionlist>\n</revisionlist>\n")
      expect(Project.deleted?('never-existed-before')).to be_falsey
    end

    it 'returns true if _history element has elements' do
      allow_any_instance_of(ProjectFile).to receive(:content).with(deleted: 1).and_return(
        "<revisionlist>\n  <revision rev=\"1\" vrev=\"\">\n    <srcmd5>d41d8cd98f00b204e9800998ecf8427e</srcmd5>\n    " \
        "<version></version>\n    <time>1498113679</time>\n    <user>Admin</user>\n    <comment>1</comment>\n  " \
        "</revision>\n</revisionlist>\n"
      )

      expect(Project.deleted?('very-nice-project-name')).to be_truthy
    end
  end

  describe '.restore' do
    let(:admin_user) { create(:admin_user, login: 'Admin') }
    let(:deleted_project) do
      create(:project_with_packages,
             name:                'project_used_for_restoration',
             title:               'restoration_project_title',
             package_title:       'restoration_title',
             package_description: 'restoration_desc',
             package_name:        'restoration_package')
    end

    # make sure it's gone even if some previous test failed
    def reset_project_in_backend
      Backend::Api::Sources::Project.delete 'project_used_for_restoration' if CONFIG['global_write_through']
    rescue ActiveXML::Transport::NotFoundError
    end

    before do
      login admin_user
    end

    it 'sets the user that restored the project in the history element' do
      reset_project_in_backend
      deleted_project.destroy!
      Project.restore(deleted_project.name, user: admin_user.login)

      meta = Xmlhash.parse(ProjectFile.new(project_name: deleted_project.name, name: '_history').content(deleted: 1))
      expect(meta.elements('revision').last['user']).to eq(admin_user.login)
    end

    it 'project meta gets properly updated' do
      reset_project_in_backend
      old_project_meta_xml = ProjectMetaFile.new(project_name: deleted_project.name).content
      deleted_project.destroy!

      restored_project = Project.restore(deleted_project.name)
      expect(restored_project.meta.content).to eq(old_project_meta_xml)
    end

    context 'on a project with packages' do
      let(:package1) { deleted_project.packages.first }
      let(:package1_meta_before_deletion) { package1.render_xml }
      let(:package2) { deleted_project.packages.last }
      let(:package2_meta_before_deletion) { package2.render_xml }

      before do
        reset_project_in_backend
        deleted_project.destroy!
      end

      subject { Project.restore('project_used_for_restoration') }

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

      it { expect(Project.deleted?(project.name)).to be_truthy }
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
    end

    subject! { project.render_relationships(xml) }

    it { expect(xml).to have_received(:person).with(userid: user.login, role: 'bugowner') }
    it { expect(xml).to have_received(:group).with(groupid: group.title, role: 'bugowner') }
  end

  describe '#remove_all_persons' do
    let!(:project) { create(:project) }
    let!(:user) { create(:user) }
    let!(:relationship) do
      create(:relationship, project: project, user: user)
    end

    before do
      User.current = user
    end

    subject! { project.remove_all_persons }

    it 'deletes the relationship' do
      expect(Relationship.exists?(relationship.id)).to be_falsey
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
      User.current = groups_user.user
    end

    subject! { project.remove_all_groups }

    it 'deletes the relationship' do
      expect(Relationship.exists?(relationship.id)).to be_falsey
    end
  end

  describe '#add_maintainer' do
    subject { create(:user).home_project }

    it_behaves_like 'makes a user a maintainer of the subject'
  end

  describe '#basename' do
    subject { create(:project, name: 'foo:bar:baz') }

    it "returns the lowest level of ':' seperated subproject names" do
      expect(subject.basename).to eq('baz')
    end
  end

  describe '#do_project_release' do
    let(:user) { create(:confirmed_user, login: 'tux') }
    let(:project) { user.home_project }
    let!(:package) { create(:package_with_revisions, name: 'my_package_release', project: project) }
    let(:project_release) { create(:project, name: "#{user.home_project}:staging") }
    let(:repository) { create(:repository, project: project) }
    let(:repository_release) { create(:repository, project: project_release) }
    let!(:release_target) { create(:release_target, target_repository: repository_release, repository: repository) }

    before do
      User.current = user
      allow_any_instance_of(Package).to receive(:target_name).and_return('my_release_target')
    end

    it "uses the package's release target name when releasing the package" do
      project.do_project_release(user: user)
      expect(project_release.packages.where(name: 'my_release_target')).to exist
    end
  end
end
