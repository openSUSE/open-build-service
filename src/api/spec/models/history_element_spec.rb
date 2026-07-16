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
        let(:managers_group) { instance_double(Group, title: 'managers') }
        let(:staging_workflow) { instance_double(Staging::Workflow, managers_group: managers_group) }
        let(:staging_project) { instance_double(Project, staging_workflow: staging_workflow) }
        let(:review) { instance_double(Review, for_group?: true, by_group: 'managers') }
        let(:request) { instance_double(BsRequest, staged_request?: true, staging_project: staging_project) }

        before { allow(element).to receive_messages(review: review, request: request) }

        it { is_expected.to be_staged_review }
      end
    end
  end
end
