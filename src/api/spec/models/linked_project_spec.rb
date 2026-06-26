RSpec.describe LinkedProject do
  describe 'validations' do
    it { is_expected.to belong_to(:project) }

    describe '.validate_target' do
      let(:linked_project) do
        build(:linked_project, linked_db_project: create(:project),
                               linked_remote_project_name: 'openSUSE.org:home:hennevogel')
      end

      before do
        linked_project.valid?
      end

      it { expect(linked_project.errors).to contain_exactly('can not have both linked_db_project and linked_remote_project_name') }
    end

    describe '.validate_duplicates local' do
      let(:project) { create(:project) }
      let(:link_target) { create(:project) }
      let!(:duplicated_linked_project) { create(:linked_project, project: project, linked_db_project: link_target) }
      let(:linked_project) { build(:linked_project, project: project, linked_db_project: link_target) }

      before do
        linked_project.valid?
      end

      it { expect(linked_project.errors).to contain_exactly("Db project already linked with '#{link_target.name}'") }
    end

    describe '.validate_duplicates remote' do
      let(:project) { create(:project) }
      let!(:duplicated_linked_project) { create(:linked_project, project: project, linked_remote_project_name: 'link_target') }
      let(:linked_project) { build(:linked_project, project: project, linked_remote_project_name: 'link_target') }

      before do
        linked_project.valid?
      end

      it { expect(linked_project.errors).to contain_exactly("Db project already linked with 'link_target'") }
    end

    describe '.validate_cycles self' do
      let(:project) { create(:project) }
      let(:linked_project) { build(:linked_project, project: project, linked_db_project: project) }

      before do
        linked_project.valid?
      end

      it { expect(linked_project.errors).to contain_exactly("The link target '#{project}' links to a project that links to us, cycles are not allowed") }
    end

    describe '.validate_cycles' do
      let(:project) { create(:project) }
      let(:link_of_link) { create(:linked_project, linked_db_project: project) }
      let(:linked_project) { build(:linked_project, project: project, linked_db_project: link_of_link.project) }

      before do
        linked_project.valid?
      end

      it { expect(linked_project.errors).to contain_exactly("The link target '#{link_of_link.project}' links to a project that links to us, cycles are not allowed") }
    end

    describe '.validate_access_flag_equality flag enable' do
      let(:project) { create(:project) }
      let(:link_target) do
        project = create(:project)
        project.flags.create(flag: 'access', status: 'disable')

        project
      end
      let(:linked_project) { build(:linked_project, project: project, linked_db_project: link_target) }

      before do
        linked_project.valid?
      end

      it { expect(linked_project.errors).to contain_exactly("The link target '#{link_target}' needs to have the same read access protection level") }
    end

    describe '.validate_access_flag_equality flag disable' do
      let(:project) { create(:project) }
      let(:link_target) do
        project = create(:project)
        project.flags.create(flag: 'access', status: 'enable')

        project
      end
      let(:linked_project) { build(:linked_project, project: project, linked_db_project: link_target) }

      it { expect(linked_project).to be_valid }
    end
  end
end
