RSpec.describe DecisionFavoredWithProjectDeletion do
  let(:decision) { build(:decision_favored_with_project_deletion) }

  describe 'validations' do
    context 'when the reportable is not a project' do
      let(:decision) do
        build(:decision_favored_with_project_deletion).tap do |decision|
          decision.reports.first.reportable = create(:comment_package)
        end
      end

      it 'is invalid' do
        expect(decision).not_to be_valid
        expect(decision.errors[:reportable_type]).to include('The reportable must be a project for this decision type.')
      end
    end

    context 'when the project can not be deleted' do
      before do
        allow(decision.reports.first.reportable).to receive(:check_weak_dependencies?).and_return(false)
      end

      it 'is invalid' do
        expect(decision).not_to be_valid
        expect(decision.errors[:base]).to include(a_string_matching(/can't be removed/))
      end
    end

    context 'when the reportable is a project that can be deleted' do
      it 'is valid' do
        expect(decision).to be_valid
      end
    end
  end

  describe '.display?' do
    context 'when the reportable is a project' do
      it 'returns true' do
        expect(described_class.display?(create(:project))).to be(true)
      end
    end

    context 'when the reportable is not a project' do
      it 'returns false' do
        expect(described_class.display?(create(:comment_package))).to be(false)
      end
    end
  end

  describe '.display_name' do
    it 'returns the expected label' do
      expect(described_class.display_name).to eq('favor and delete the project')
    end
  end

  describe '#deletes_target_record?' do
    it 'returns true' do
      expect(decision.deletes_target_record?).to be(true)
    end
  end

  describe 'after_create callbacks' do
    it 'deletes the reported project' do
      project = decision.reports.first.reportable

      decision.save!

      expect(Project.exists?(project.id)).to be(false)
    end

    it 'creates a FavoredDecision event' do
      expect { decision.save! }.to change(Event::FavoredDecision, :count).by(1)
    end
  end
end
