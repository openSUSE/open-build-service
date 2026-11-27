RSpec.describe HistoryElement do
  describe 'HistoryElement::RequestDeleted' do
    it 'has the correct color' do
      expect(HistoryElement::RequestDeleted.new.color).to eq('red')
    end

    it 'has a correct description' do
      expect(HistoryElement::RequestDeleted.new.description).to eq('Request was deleted')
    end
  end

  describe 'HistoryElement::ReviewAccepted' do
    describe '#staged_review?' do
      subject(:element) { create(:history_element_request_review_accepted_with_review_by_group) }

      context 'when the request is not staged' do
        it { is_expected.not_to be_staged_review }
      end

      context 'when the review is for the staging workflow managers group' do
        subject(:element) { create(:history_element_review_accepted, op_object_id: bs_request.reviews.first.id) }

        let(:staging_workflow) { create(:staging_workflow_with_staging_projects) }
        let(:bs_request) do
          create(:bs_request_with_submit_action, review_by_group: staging_workflow.managers_group,
                                                 staging_project: staging_workflow.staging_projects.first)
        end

        it { is_expected.to be_staged_review }
      end
    end
  end
end
