RSpec.describe Repository do
  describe 'validations' do
    it { is_expected.to validate_length_of(:name).is_at_least(1).is_at_most(200) }
    it { is_expected.to belong_to(:project) }

    it 'validates uniqueness of name' do
      repository = create(:repository)
      expect(repository).to validate_uniqueness_of(:name)
        .scoped_to(:db_project_id, :remote_project_name)
        .with_message("#{repository.name} is already used by a repository of this project")
    end

    it { is_expected.not_to(allow_value('_foo').for(:name)) }
    it { is_expected.not_to(allow_value('f:oo').for(:name)) }
    it { is_expected.not_to(allow_value('f/oo').for(:name)) }
    it { is_expected.not_to(allow_value("f\noo").for(:name)) }
    it { is_expected.to allow_value('fOO_-§$&!#+~()=?\\"').for(:name) }
    it { is_expected.to allow_value('f').for(:name) }

    describe '#remote_project_name_not_nil' do
      subject! { repository.valid? }

      context 'with remote_project_name = nil' do
        let(:repository) { build(:repository, remote_project_name: nil) }

        it { is_expected.to be_falsey }

        it 'has an error on remote_project_name' do
          expect(repository.errors[:remote_project_name].count).to eq(1)
        end
      end

      context 'with remote_project_name = ""' do
        let(:repository) { build(:repository, remote_project_name: '') }

        it { is_expected.to be_truthy }

        it 'does not have an error on remote_project_name' do
          expect(repository.errors[:remote_project_name].count).to eq(0)
        end
      end
    end

    describe '.cycles' do
      subject { repository.cycles('x64_64') }

      let(:repository) { create(:repository) }

      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:builddepinfo).and_return(cycles_xml)
      end

      context 'with no cycle' do
        let(:cycles_xml) do
          <<-XML_DATA
            <builddepinfo>
            </builddepinfo>
          XML_DATA
        end

        it do
          expect(subject).to eq([])
        end
      end

      context 'with one cycle and one intersection' do
        let(:cycles_xml) do
          file_fixture('builddepinfo_one_cycle_one_intersection.xml').read
        end

        it do
          expect(subject).to eq([%w[a b c]])
        end
      end

      context 'with one cycle and multiple intersections' do
        let(:cycles_xml) do
          file_fixture('builddepinfo_one_cycle_multiple_intersections.xml').read
        end

        it do
          expect(subject).to eq([%w[a b c d]])
        end
      end

      context 'with multiple cycles, each with one intersection' do
        let(:cycles_xml) do
          file_fixture('builddepinfo_multiple_cycles_one_intersection.xml').read
        end

        it do
          expect(subject).to eq([%w[a b c], %w[x y z]])
        end
      end

      context 'with multiple cycles, each with multiple intersections' do
        let(:cycles_xml) do
          file_fixture('builddepinfo_multiple_cycles_multiple_intersections.xml').read
        end

        it do
          expect(subject).to eq([%w[a b c d], %w[w x y z], %w[m n o p]])
        end
      end
    end
  end

  describe '#copy_to' do
    subject { repository.copy_to(project) }

    let(:repository) { create(:repository, architectures: %w[i586 x86_64]) }
    let!(:path_elements) { create_list(:path_element, 3, repository: repository) }
    let(:project) { create(:project) }

    it 'copies a repository to a project' do
      expect(subject.name).to eq(repository.name)
      expect(subject).not_to eq(repository)
      expect(subject).to be_persisted
      expect(subject.project).to eq(project)
    end

    it { expect(subject.architectures.pluck(:name)).to contain_exactly('i586', 'x86_64') }

    it 'copies the path elements of the repository' do
      repository.path_elements.reload.each do |path|
        expect(subject.path_elements.where(repository_id: path.repository_id, position: path.position)).to exist
      end
    end

    context 'when the repository has DoD repositories' do
      let!(:dod_repository) { create(:download_repository, repository: repository) }

      it { expect(subject.download_repositories.pluck(:arch, :url)).to contain_exactly([dod_repository.arch, dod_repository.url]) }
    end
  end

  describe '#new_from_distribution' do
    subject { subject_repository }

    let(:target_project) { create(:project) }
    let(:project) { create(:project_with_repository) }
    let(:distribution) { create(:distribution, project: project, repository: project.repositories.first.name) }
    let(:subject_repository) do
      repository = Repository.new_from_distribution(distribution)
      repository.project = target_project
      repository.save!
      repository
    end

    it 'builds a valid repository from a distribution' do
      expect(subject.name).to eq(distribution.reponame)
      expect(subject).to be_persisted
    end

    it { expect(subject.architectures.pluck(:name)).to contain_exactly('x86_64', 'ppc64le') }

    it 'sets the path elements of the repository' do
      expect(subject.path_elements.where(repository_id: project.repositories.first.id)).to exist
    end
  end
end
