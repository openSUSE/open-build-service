RSpec.describe DecisionFavoredWithPackageDeletion do
  describe '.display?' do
    it { expect(described_class.display?(create(:package))).to be(true) }
    it { expect(described_class.display?(create(:project))).to be(false) }
  end

  describe '#delete_package' do
    context 'when reporting a package' do
      let(:decision) { build(:decision_favored_with_package_deletion) }

      it 'destroys the reported package' do
        package = decision.reports.first.reportable

        expect { decision.delete_package }.to change(Package, :count).by(-1)
        expect(Package.exists?(package.id)).to be(false)
      end
    end

    context 'when reporting something other than a package' do
      let(:project) { create(:project) }
      let!(:decision) do
        build(:decision_favored_with_package_deletion, reports: [create(:report, reportable: project, reason: 'This is spam!')])
      end

      it 'does not destroy the reportable' do
        expect { decision.delete_package }.not_to change(Project, :count)
      end
    end
  end
end
