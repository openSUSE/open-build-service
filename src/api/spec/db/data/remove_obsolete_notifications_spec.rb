require Rails.root.join('db/data/20200326170855_remove_obsolete_notifications.rb')

RSpec.describe RemoveObsoleteNotifications, type: :migration do
  describe 'up' do
    # 'Event::RequestCreate'
    let!(:request_create_with_notifiable) { create(:notification_for_request, :request_created) }
    let!(:request_create_without_notifiable) { create(:notification_for_request, :request_created, notifiable: nil) }
    # 'Event::RequestStatechange'
    let!(:request_state_change_with_notifiable) { create(:notification_for_request, :request_state_change) }
    let!(:request_state_change_without_notifiable) { create(:notification_for_request, :request_state_change, notifiable: nil) }
    # 'Event::ReviewWanted'
    let!(:review_wanted_with_notifiable) { create(:notification_for_request, :review_wanted) }
    let!(:review_wanted_without_notifiable) { create(:notification_for_request, :review_wanted, notifiable: nil) }
    # 'Event::CommentForRequest'
    let!(:comment_for_request_with_notifiable) { create(:notification_for_comment, :comment_for_request) }
    let!(:comment_for_request_without_notifiable) { create(:notification_for_comment, :comment_for_request, notifiable: nil) }
    # 'Event::CommentForProject'
    let!(:comment_for_project_with_notifiable) { create(:notification_for_comment, :comment_for_project) }
    let!(:comment_for_project_without_notifiable) { create(:notification_for_comment, :comment_for_project, notifiable: nil) }
    # 'Event::CommentForPackage'
    let!(:comment_for_package_with_notifiable) { create(:notification_for_comment, :comment_for_package) }
    let!(:comment_for_package_without_notifiable) { create(:notification_for_comment, :comment_for_package, notifiable: nil) }

    before do
      RemoveObsoleteNotifications.new.up
    end

    it 'deletes all the notifications without notifiable' do
      expect(Notification.where(notifiable_id: nil, notifiable_type: nil).count).to be_zero
    end

    it 'deletes all the notifications except CommentForProject and CommentForPackage' do
      expect(Notification.count).to eq(2)
      expect(Notification.pluck(:event_type)).to contain_exactly('Event::CommentForProject', 'Event::CommentForPackage')
    end
  end
end
