RSpec.describe DecisionFavoredWithUserDeletion do
  describe '#delete_user' do
    let(:moderator) { create(:confirmed_user) }
    let(:comment) { decision.reports.first.reportable }
    let(:decision) { create(:decision_favored_with_user_deletion) }

    context 'when the user is not deleted yet' do
      before { login moderator }

      it 'deletes the comment creator' do
        expect(comment.user.state).to eql('deleted')
      end
    end
  end
end
