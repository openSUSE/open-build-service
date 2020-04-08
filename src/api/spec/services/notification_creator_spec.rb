require 'rails_helper'

RSpec.describe NotificationCreator do
  let(:user_bob) { create(:confirmed_user, login: 'bob') }
  let(:user_kim) { create(:confirmed_user, login: 'kim') }
  let(:commenter) { create(:confirmed_user, login: 'ann') }

  let!(:bob_subscription) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user_bob) }
  let!(:kim_subscription) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user_kim) }

  let(:project) { create(:project, name: 'bobkim_project') }
  let!(:relationship_bob) { create(:relationship_project_user, user: user_bob, project: project) }
  let!(:relationship_kim) { create(:relationship_project_user, user: user_kim, project: project) }

  let!(:comment_for_project) { create(:comment_project, commentable: project, user: commenter, body: 'blah') }
  let(:event) { Event::Base.where(eventtype: 'Event::CommentForProject').last }
  let(:comment_notifications) { Notification.where(notifiable_type: 'Comment') }

  describe '#call' do
    subject! { NotificationCreator.new(event).call }

    it 'creates only one CommentForProject notifications for subscriber' do
      expect(Notification::RssFeedItem.count).to eq(2)
      expect(Notification::RssFeedItem.where(event_type: 'Event::CommentForProject').pluck(:subscriber_id)).to match_array([user_bob.id, user_kim.id])
    end

    context 'when tries to create notifications twice' do
      it 'creates only one CommentForProject notifications for subscriber and do not duplicate them' do
        expect(Notification::RssFeedItem.count).to eq(2)
        # Tries to create the same notifications twice:
        expect { NotificationCreator.new(event).call }.not_to change(Notification::RssFeedItem, :count)
      end
    end
  end
end
