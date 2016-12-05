require "rails_helper"

RSpec.describe Project do
  let!(:project) { create(:project) }
  let(:leap_project) { create(:project, name: 'openSUSE_Leap') }
  let(:attribute_type) { AttribType.find_by_namespace_and_name!('OBS', 'ImageTemplates') }

  describe "validations" do
    it {
      is_expected.to validate_inclusion_of(:kind).
        in_array(["standard", "maintenance", "maintenance_incident", "maintenance_release"])
    }
    it { is_expected.to validate_length_of(:name).is_at_most(200) }
    it { is_expected.to validate_length_of(:title).is_at_most(250) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { should_not allow_value("_foo").for(:name) }
    it { should_not allow_value("foo::bar").for(:name) }
    it { should_not allow_value("ends_with_:").for(:name) }
    it { should allow_value("fOO:+-").for(:name) }
  end

  describe ".image_templates" do
    let!(:attrib) { create(:attrib, attrib_type: attribute_type, project: leap_project) }

    it { expect(Project.image_templates).to eq([leap_project]) }
  end

  describe "#update_repositories" do
    let!(:repository_1) { create(:repository, name: 'repo_1', rebuild: "direct", project: project) }
    let!(:repository_2) { create(:repository, name: 'repo_2', project: project) }
    let!(:repository_3) { create(:repository, name: 'repo_3', project: project) }

    context "updating repository elements" do
      before do
        xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_1" />
              <repository name="new_repo" rebuild="local" block="never" linkedbuild="all" />
            </project>
          EOF
        )
        project.update_repositories(xml_hash, false)
      end

      it "updates repositories association of a project" do
        expect(project.repositories.count).to eq 2
        expect(project.repositories.where(name: "repo_1")).to exist
        expect(project.repositories.where(name: "new_repo")).to exist
      end

      it "updates repository attributes of existing repositories" do
        expect(repository_1.reload.rebuild).to be nil
        expect(repository_1.block).to be nil
        expect(repository_1.linkedbuild).to be nil
      end

      it "imports repository attributes of newly created repositories" do
        new_repo = project.repositories.find_by(name: "new_repo")
        expect(new_repo.rebuild).to eq "local"
        expect(new_repo.block).to eq "never"
        expect(new_repo.linkedbuild).to eq "all"
      end
    end

    describe "repositories with release targets" do
      let!(:target_project) { create(:project, name: "target_project") }
      let!(:target_repository) { create(:repository, name: 'target_repo', project: target_project) }
      let!(:remote_project) { create(:project, name: "remote_project", remoteurl: "http://myOBS.org") }
      let!(:remote_repository) {
        create(:repository, name: 'remote_repo', remote_project_name: "remote_project", project: remote_project)
      }
      let!(:release_target) { create(:release_target, repository: repository_1) }

      it "updates release targets" do
        xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_1">
                <releasetarget project="#{target_project.name}" repository="#{target_repository.name}" trigger="manual" />
              </repository>
            </project>
          EOF
        )
        project.update_repositories(xml_hash, false)

        expect(repository_1.release_targets.count).to eq 1
        expect(repository_1.release_targets.first.trigger).to eq "manual"
      end

      it "raises an error if target repository does not exist" do
        xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_1">
                <releasetarget project="#{target_project.name}" repository="nonexistant_repo" trigger="manual" />
              </repository>
            </project>
          EOF
        )
        expect { project.update_repositories(xml_hash, false) }.to raise_error(
          Project::SaveError, "Unknown target repository 'target_project/nonexistant_repo'"
        )
      end

      it "raises an error if target repository is a remote repository" do
        xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_1">
                <releasetarget project="#{remote_project.name}" repository="#{remote_repository.name}" trigger="manual" />
              </repository>
            </project>
          EOF
        )
        expect { project.update_repositories(xml_hash, false) }.to raise_error(
          Project::SaveError, "Can not use remote repository as release target '#{remote_project.name}/remote_repo'"
        )
      end
    end

    describe "hostsystem" do
      let!(:target_project) { create(:project, name: "target_project") }
      let!(:target_repository) { create(:repository, name: 'target_repo', project: target_project) }

      before do
        repository_1.hostsystem = target_repository
        repository_1.save!

        @xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_1" />
              <repository name="repo_2">
                <hostsystem repository="#{target_repository.name}" project="#{target_project.name}" />
              </repository>
            </project>
          EOF
        )
      end

      it "updates the hostsystem of a repository" do
        project.update_repositories(@xml_hash, false)
        expect(repository_1.reload.hostsystem).to be nil
        expect(repository_2.reload.hostsystem).to eq target_repository
      end

      it "raises an error if hostsystem refers itself" do
        xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_2">
                <hostsystem repository="repo_2" project="#{project.name}" />
              </repository>
            </project>
          EOF
        )
        expect { project.update_repositories(xml_hash, false) }.to raise_error(
          Project::SaveError, "Using same repository as hostsystem element is not allowed"
        )
      end

      it "raises an error if target repository does not exist" do
        target_repository.destroy
        expect { project.update_repositories(@xml_hash, false) }.to raise_error(
          Project::SaveError, "Unknown target repository 'target_project/target_repo'"
        )
      end
    end

    describe "repository architecture" do
      it "should create architectures for the repository" do
        xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_1">
                <arch>x86_64</arch>
                <arch>i586</arch>
              </repository>
            </project>
          EOF
        )
        project.update_repositories(xml_hash, false)

        expect(repository_1.architectures.map(&:name).sort).to eq ["i586", "x86_64"]
        expect(repository_1.repository_architectures.where(position: 1).first.architecture.name).to eq "x86_64"
        expect(repository_1.repository_architectures.where(position: 2).first.architecture.name).to eq "i586"
      end

      it "should raise an error for unkown architectures" do
        xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_1">
                <arch>foo</arch>
              </repository>
            </project>
          EOF
        )
        expect { project.update_repositories(xml_hash, false) }.to raise_error(
          Project::SaveError, "unknown architecture: 'foo'"
        )
      end

      it "should raise an error for duplicated architecture elements" do
        xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_1">
                <arch>i586</arch>
                <arch>i586</arch>
              </repository>
            </project>
          EOF
        )
        expect { project.update_repositories(xml_hash, false) }.to raise_error(
          Project::SaveError, "double use of architecture: 'i586'"
        )
      end
    end

    describe "download repositories" do
      before do
        xml_hash = Xmlhash.parse(
          <<-EOF
            <project name="#{project.name}">
              <repository name="repo_1" />
              <repository name="dod_repo">
                <download arch='i586' url='http://opensuse.org' repotype='rpmmd'>
                  <archfilter>i586, noarch</archfilter>
                  <master url='http://master.opensuse.org' sslfingerprint='my_fingerprint'/>
                  <pubkey>my_pubkey</pubkey>
                </download>
                <arch>i586</arch>
              </repository>
            </project>
          EOF
        )
        project.update_repositories(xml_hash, false)
      end

      it "updates download repositories of a repository" do
        expect(repository_1.download_repositories).to be_empty

        dod_repo = project.repositories.find_by(name: "dod_repo")
        expect(dod_repo).not_to be_nil
        expect(dod_repo.download_repositories.count).to eq 1
      end

      it "updates download_repository attributes" do
        download_repository = project.repositories.find_by(name: "dod_repo").download_repositories.first
        expect(download_repository.arch).to eq "i586"
        expect(download_repository.repotype).to eq "rpmmd"
        expect(download_repository.url).to eq "http://opensuse.org"
        expect(download_repository.archfilter).to eq "i586, noarch"
        expect(download_repository.masterurl).to eq "http://master.opensuse.org"
        expect(download_repository.mastersslfingerprint).to eq "my_fingerprint"
        expect(download_repository.pubkey).to eq "my_pubkey"
      end
    end

    describe "path elements" do
      let!(:other_project) { create(:project, name: "other_project") }
      let!(:other_projects_repository) { create(:repository, name: 'other_repo', project: other_project) }
      let!(:path_element) { create(:path_element, repository: repository_3) }

      context "valid usecase" do
        before do
          xml_hash = Xmlhash.parse(
            <<-EOF
              <project name="#{project.name}">
                <repository name="repo_1">
                  <path project="other_project" repository="other_repo" />
                  <path project="#{project.name}" repository="repo_3" />
                </repository>
                <repository name="repo_2">
                  <path project="#{project.name}" repository="repo_3" />
                </repository>
                <repository name="repo_3" />
              </project>
            EOF
          )
          project.update_repositories(xml_hash, false)
        end

        it "updates path elements" do
          expect(repository_1.path_elements.count).to eq 2

          expect(repository_1.path_elements.find_by(position: 1).link.name).to eq "other_repo"
          expect(repository_1.path_elements.find_by(position: 2).link.name).to eq "repo_3"
        end

        it "can handle dependencies between repositories" do
          expect(repository_2.path_elements.count).to eq 1
          expect(repository_2.path_elements.find_by(position: 1).link.name).to eq "repo_3"
        end

        it "removes path elements" do
          expect(repository_3.path_elements.count).to eq 0
        end
      end

      context "invalid usecase" do
        it "raises an error when a repository refers itself" do
          xml_hash = Xmlhash.parse(
            <<-EOF
              <project name="#{project.name}">
                <repository name="repo_1">
                  <path project="#{project.name}" repository="repo_1" />
                </repository>
              </project>
            EOF
          )
          expect { project.update_repositories(xml_hash, false) }.to raise_error(
            Project::SaveError, "Using same repository as path element is not allowed"
          )
        end

        it "raises an error for non existant repository links" do
          xml_hash = Xmlhash.parse(
            <<-EOF
              <project name="#{project.name}">
                <repository name="repo_1">
                  <path project="other_project" repository="nonexistant" />
                </repository>
              </project>
            EOF
          )
          expect { project.update_repositories(xml_hash, false) }.to raise_error(
            Project::SaveError, "unable to walk on path 'other_project/nonexistant'"
          )
        end
      end
    end
  end

  describe "#store" do
    before do
      allow(project).to receive(:save!).and_return(true)
      allow(project).to receive(:write_to_backend).and_return(true)
      project.commit_opts = { comment: 'the comment' }
    end

    context "without commit_opts parameter" do
      it "does not overwrite the commit_opts" do
        project.store
        expect(project.commit_opts).to eq({ comment: 'the comment' })
      end
    end

    context "with commit_opts parameter" do
      it "does overwrite the commit_opts" do
        project.store({ comment: 'a new comment'})
        expect(project.commit_opts).to eq({ comment: 'a new comment' })
      end
    end
  end

  describe "#has_distribution" do
    context "remote distribution" do
      let(:remote_project) {create(:remote_project, name: "openSUSE.org")}
      let(:remote_distribution) { create(:repository, name: "snapshot", remote_project_name: "openSUSE:Factory", project: remote_project) }
      let(:other_remote_distribution) { create(:repository, name: "standard", remote_project_name: "openSUSE:Leap:42.1", project: remote_project) }
      let(:repository) { create(:repository, name: "openSUSE_Tumbleweed", project: project) }
      let!(:path_element) { create(:path_element, parent_id: repository.id, repository_id: remote_distribution.id, position: 1)}

      it { expect(project.has_distribution("openSUSE.org:openSUSE:Factory", "snapshot")).to be(true) }
      it { expect(project.has_distribution("openSUSE.org:openSUSE:Leap:42.1", "standard")).to be(false) }
    end

    context "local distribution" do
      context "with linked distribution" do
        let(:distribution) { create(:project, name: "BaseDistro2.0") }
        let(:distribution_repository) { create(:repository, name: "BaseDistro2_repo", project: distribution) }
        let(:repository) { create(:repository, name: "Base_repo2", project: project) }
        let!(:path_element) { create(:path_element, parent_id: repository.id, repository_id: distribution_repository.id, position: 1)}

        it { expect(project.has_distribution("BaseDistro2.0", "BaseDistro2_repo")).to be(true) }
      end

      context "with not linked distribution" do
        let(:not_linked_distribution) { create(:project, name: "BaseDistro") }
        let!(:not_linked_distribution_repository) { create(:repository, name: "BaseDistro_repo", project: not_linked_distribution) }

        it { expect(project.has_distribution("BaseDistro", "BaseDistro_repo")).to be(false) }
      end

      context "with linked distribution but wrong query" do
        let(:other_distribution) { create(:project, name: "BaseDistro3.0") }
        let!(:other_distribution_repository) { create(:repository, name: "BaseDistro3_repo", project: other_distribution) }
        let(:other_repository) { create(:repository, name: "Base_repo3", project: project) }
        let!(:path_element) { create(:path_element, parent_id: other_repository.id, repository_id: other_distribution_repository.id, position: 1)}
        it { expect(project.has_distribution("BaseDistro3.0", "standard")).to be(false) }
        it { expect(project.has_distribution("BaseDistro4.0", "BaseDistro3_repo")).to be(false) }
      end
    end
  end

  describe '#image_template?' do
    let!(:image_templates_attrib) { create(:attrib, attrib_type: attribute_type, project: leap_project) }
    let(:tumbleweed_project) { create(:project, name: 'openSUSE_Tumbleweed') }

    it { expect(leap_project.image_template?).to be(true) }
    it { expect(tumbleweed_project.image_template?).to be(false) }
  end
end
