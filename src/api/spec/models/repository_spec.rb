require 'rails_helper'

RSpec.describe Repository do
  describe 'validations' do
    it { is_expected.to validate_length_of(:name).is_at_least(1).is_at_most(200) }
    it { is_expected.to validate_presence_of(:db_project_id) }
    it 'validates uniqueness of name' do
      repository = create(:repository)
      expect(repository).to validate_uniqueness_of(:name).
        scoped_to(:db_project_id, :remote_project_name).
        with_message("#{repository.name} is already used by a repository of this project")
    end
    it { should_not allow_value('_foo').for(:name) }
    it { should_not allow_value('f:oo').for(:name) }
    it { should_not allow_value('f/oo').for(:name) }
    it { should_not allow_value("f\noo").for(:name) }
    it { should allow_value('fOO_-§$&!#+~()=?\\"').for(:name) }
    it { should allow_value('f').for(:name) }

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
      let(:repository) { create(:repository) }
      subject { repository.cycles('x64_64') }

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
          expect(subject).to eq([['a', 'b', 'c']])
        end
      end

      context 'with one cycle and multiple intersections' do
        let(:cycles_xml) do
          file_fixture('builddepinfo_one_cycle_multiple_intersections.xml').read
        end

        it do
          expect(subject).to eq([['a', 'b', 'c', 'd']])
        end
      end

      context 'with multiple cycles, each with one intersection' do
        let(:cycles_xml) do
          file_fixture('builddepinfo_multiple_cycles_one_intersection.xml').read
        end

        it do
          expect(subject).to eq([['a', 'b', 'c'], ['x', 'y', 'z']])
        end
      end

      context 'with multiple cycles, each with multiple intersections' do
        let(:cycles_xml) do
          file_fixture('builddepinfo_multiple_cycles_multiple_intersections.xml').read
        end

        it do
          expect(subject).to eq([['a', 'b', 'c', 'd'], ['w', 'x', 'y', 'z'], ['m', 'n', 'o', 'p']])
        end
      end
    end
  end
end
