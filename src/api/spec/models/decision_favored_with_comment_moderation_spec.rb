RSpec.describe DecisionFavoredWithCommentModeration do
  describe '#moderate_comment' do
    let(:moderator) { create(:confirmed_user) }
    let(:comment) { decision.reports.first.reportable }
    let(:decision) { create(:decision_favored_with_comment_moderation) }

    context 'when the reportable is not moderated yet' do
      before { login moderator }

      it 'moderates the comment' do
        expect(comment.moderator).to eql(moderator)
      end
    end
  end
end
