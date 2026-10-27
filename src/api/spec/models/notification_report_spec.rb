RSpec.describe NotificationReport do
  describe '#link_text' do
    context 'when the notification is about a cleared decision' do
      let(:report) { create(:report) }
      let(:decision) { create(:decision_cleared, reports: [report]) }
      let(:notification) { create(:notification_for_report, :cleared_decision, notifiable: decision) }

      it { expect(notification.link_text).to eq('Cleared Comment Report') }

      context 'when the reportable has been deleted' do
        before do
          report.reportable.destroy
          report.reload
        end

        it { expect(notification.link_text).to eq('Cleared Report') }
      end
    end

    context 'when the notification is about a favored decision' do
      let(:report) { create(:report) }
      let(:decision) { create(:decision_favored, reports: [report]) }
      let(:notification) { create(:notification_for_report, :favored_decision, notifiable: decision) }

      it { expect(notification.link_text).to eq('Favored Comment Report') }

      context 'when the reportable has been deleted' do
        before do
          report.reportable.destroy
          report.reload
        end

        it { expect(notification.link_text).to eq('Favored Report') }
      end
    end
  end
end
