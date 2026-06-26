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

  describe '#other_reports_from_reportable' do
    let(:comment) { report.reportable }
    let(:report) { create(:report) }
    let!(:another_report) { create(:report, reportable: comment) }

    it { expect(report.other_reports_from_reportable).to contain_exactly(another_report) }

    context 'when reportable is nil' do
      let(:report) { create(:report) }

      before do
        report.reportable.destroy
        report.reload
      end

      it { expect(report.other_reports_from_reportable).to eq([]) }
    end
  end
end
