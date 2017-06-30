class AlterNotificationsToUsePolymorphic < ActiveRecord::Migration[5.0]
  def change
    add_reference :notifications, :subscriber, polymorphic: true

    Notification.find_in_batches batch_size: 500 do |batch|
      batch.each do |notification|
        if notification.user_id
          notification.subscriber_type = 'User'
          notification.subscriber_id = notification.user_id
        else
          notification.subscriber_type = 'Group'
          notification.subscriber_id = notification.group_id
        end
        notification.save!
      end
    end

    remove_reference :notifications, :group
    remove_reference :notifications, :user
  end
end
