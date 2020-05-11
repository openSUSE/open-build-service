require 'rails_helper'

RSpec.describe NotificationCreator do
  let(:user_bob) { create(:confirmed_user, login: 'bob') }
  let(:user_kim) { create(:confirmed_user, login: 'kim') }
  let(:commenter) { create(:confirmed_user, login: 'ann') }

  let!(:bob_subscription) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user_bob, channel: :rss) }
  let!(:bob_web_subscription) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user_bob, channel: :web) }
  let!(:kim_subscription) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user_kim, channel: :rss) }

  let(:project) { create(:project, name: 'bobkim_project') }
  let!(:relationship_bob) { create(:relationship_project_user, user: user_bob, project: project) }
  let!(:relationship_kim) { create(:relationship_project_user, user: user_kim, project: project) }

  let!(:comment_for_project) { create(:comment_project, commentable: project, user: commenter, body: 'blah') }
  let(:event) { Event::Base.where(eventtype: 'Event::CommentForProject').last }
  let(:comment_notifications) { Notification.where(notifiable_type: 'Comment') }

  describe '#call' do
    subject { NotificationCreator.new(event).call }

    context 'when users has rss token' do
      before do
        user_bob.create_rss_token
        user_kim.create_rss_token

        subject
      end

      it 'creates only one CommentForProject notifications for subscriber' do
        expect(Notification.count).to eq(2)
        expect(Notification.where(event_type: 'Event::CommentForProject').pluck(:subscriber_id)).to match_array([user_bob.id, user_kim.id])
      end

      it 'creates one notification with rss and web checked' do
        expect(Notification.find_by(subscriber: user_bob)).to be_web
        expect(Notification.find_by(subscriber: user_bob)).to be_rss
      end

      it 'creates one notification with rss checked' do
        expect(Notification.find_by(subscriber: user_kim)).not_to be_web
        expect(Notification.find_by(subscriber: user_kim)).to be_rss
      end

      context 'when tries to create notifications twice' do
        it 'creates only one CommentForProject notifications for subscriber and do not duplicate them' do
          expect(Notification.count).to eq(2)
          # Tries to create the same notifications twice:
          expect { NotificationCreator.new(event).call }.not_to change(Notification, :count)
        end
      end
    end

    context "when users don't have rss token" do
      before do
        subject
      end

      it { expect(Notification.count).to eq(1) }
      it { expect(Notification.first).to be_web }
      it { expect(Notification.first).not_to be_rss }
    end
  end
end
