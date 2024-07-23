require Rails.root.join('db/data/20210205131609_remove_notifications_for_missing_notifiables.rb')
RSpec.describe RemoveNotificationsForMissingNotifiables, type: :migration do
  describe 'up' do
    let!(:notification1) { create(:notification_for_comment, :comment_for_request) }
    let!(:notification2) { create(:notification_for_comment, :comment_for_request) }

    before do
      # Simulate the wrong behaviour we had before. When a BsRequest was removed,
      # all the comments were removed as well, but not their associated notifications.
      # That happened because of a wrong association, dependent option: `delete_all` instead of `destroy`.
      notification2.notifiable.delete
    end

    it 'removes notification with non-existent notifiables' do
      expect { RemoveNotificationsForMissingNotifiables.new.up }.to change(Notification, :all)
        .from([notification1, notification2])
        .to([notification1])
    end
  end
end
