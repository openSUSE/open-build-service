RSpec.describe Report do
  describe '#reports_pointing_to_same_reportable' do
    context 'when different reportables' do
      let(:decision) { create(:decision_cleared) }
      let(:report) { build(:report, decision: decision) }

      before do
        report.save
      end

      it { expect(report.valid?).to be(false) }
      it { expect(report.errors.full_messages).to eq(['Decision has reports pointing to a different reportable. All decision reports should point to same reportable.']) }
    end

    context 'when reports are pointing to same reportable' do
      let(:report) { create(:report) }
      let(:decision) { create(:decision_cleared, reports: [report]) }
      let(:new_report) { build(:report, reportable: report.reportable, decision: decision) }

      it { expect(new_report.valid?).to be(true) }
    end
  end
end
