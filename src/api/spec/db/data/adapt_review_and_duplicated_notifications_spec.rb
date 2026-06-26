require Rails.root.join('db/data/20200702145811_adapt_review_and_duplicated_notifications.rb')

RSpec.describe AdaptReviewAndDuplicatedNotifications, type: :migration do
  describe 'up' do
    subject { AdaptReviewAndDuplicatedNotifications.new.up }

    let(:subscriber) { create(:confirmed_user) }
    let(:bs_request_with_submit_action) { create(:bs_request_with_submit_action, state: :review) }
    let(:subscriber_review) do
      create(:user_review, by_user: subscriber, user_id: subscriber.id,
                           bs_request: bs_request_with_submit_action)
    end

    context 'review notifiable' do
      before do
        create(:notification_for_request, :review_wanted, notifiable: subscriber_review, subscriber: subscriber)
        subject
      end

      it 'associates review notifications to the corresponding bs_request' do
        expect(Notification.find_by(subscriber: subscriber).notifiable).to eq(bs_request_with_submit_action)
      end

      it 'removes all review notifications' do
        expect(Notification.where(notifiable_type: 'Review')).not_to exist
      end
    end

    context 'comment and bs_request notifiable' do
      let(:comment_request) { create(:comment_request, commentable: bs_request_with_submit_action) }
      let(:comment_request02) { create(:comment_request, commentable: bs_request_with_submit_action) }

      let(:first_request_notification) do
        create(:notification_for_request, :request_state_change, notifiable: bs_request_with_submit_action,
                                                                 subscriber: subscriber, web: true)
      end
      let(:second_request_notification) do
        create(:notification_for_request, :request_state_change, notifiable: bs_request_with_submit_action,
                                                                 subscriber: subscriber, web: true)
      end
      let(:first_comment_notification) do
        create(:notification_for_comment, :comment_for_request, notifiable: comment_request,
                                                                subscriber: subscriber, web: true)
      end
      let(:second_comment_notification) do
        create(:notification_for_comment, :comment_for_request, notifiable: comment_request02,
                                                                subscriber: subscriber, web: true)
      end

      before do
        first_request_notification
        second_request_notification
        first_comment_notification
        second_comment_notification
        subject
      end

      it 'keeps the latest request notifications for the subscriber' do
        expect(Notification.find_by(notifiable: bs_request_with_submit_action, subscriber: subscriber)).to eq(second_request_notification)
      end

      it 'removes duplicated request notifications for the subscriber' do
        expect(Notification.where(notifiable: bs_request_with_submit_action, subscriber: subscriber).count).to eq(1)
      end

      it 'keeps the latest comment notifications for the subscriber' do
        expect(Notification.find_by(notifiable_type: 'Comment', subscriber: subscriber)).to eq(second_comment_notification)
      end

      it 'removes duplicated comment notifications for the subscriber' do
        expect(Notification.where(notifiable_type: 'Comment', subscriber: subscriber).count).to eq(1)
      end
    end
  end
end
