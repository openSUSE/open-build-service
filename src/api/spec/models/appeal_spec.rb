RSpec.describe Appeal do
  describe '#event_parameters' do
    let(:report) { create(:report) }
    let(:decision) { create(:decision_cleared, reports: [report]) }

    it 'creates an event with reportable_type' do
      create(:appeal, decision: decision)
      expect(Event::AppealCreated.last.payload['reportable_type']).to eq('Comment')
    end

    context 'when the reported content has been deleted' do
      before do
        report.reportable.destroy
        report.reload
      end

      it 'creates an event without error' do
        expect { create(:appeal, decision: decision) }.not_to raise_error
      end
    end
  end
end
