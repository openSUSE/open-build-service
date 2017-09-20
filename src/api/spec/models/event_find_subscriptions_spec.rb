require 'rails_helper'

RSpec.describe EventFindSubscriptions do
  describe '#subscribers' do
    let!(:comment_author) { create(:confirmed_user) }
    let!(:user1) { create(:confirmed_user) }
    let!(:user2) { create(:confirmed_user) }
    let!(:group1) { create(:group) }
    let!(:group2) { create(:group) }
    let!(:group3) { create(:group, email: '') }
    let!(:project) { create(:project, name: 'comment_project', maintainer: [user1, user2, group1, group2, group3]) }

    let!(:subscription1) { create(:event_subscription_comment_for_project, receiver_role: 'commenter', user: comment_author) }
    let!(:subscription2) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user1) }
    let!(:subscription3) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user2) }
    let!(:subscription4) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: group1) }
    let!(:subscription5) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: group2) }
    let!(:subscription6) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: group3) }

    let!(:comment) { create(:comment_project, commentable: project, body: "Hey @#{user1.login} how are things?", user: comment_author) }
    let(:event) { Event::CommentForProject.first }

    subject! { EventFindSubscriptions.new(event).subscriptions }

    it 'includes the users and groups subscribed to Event::CommentForProject' do
      expect(subject).to include(subscription2, subscription3, subscription4, subscription5)
    end

    it 'does not include the author of the comment' do
      expect(subject).not_to include(subscription1)
    end

    it 'does not include the group with no email set' do
      expect(subject).not_to include(subscription6)
    end
  end
end
