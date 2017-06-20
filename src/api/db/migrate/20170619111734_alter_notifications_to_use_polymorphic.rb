class AlterNotificationsToUsePolymorphic < ActiveRecord::Migration[5.0]
  def change
    add_reference :notifications, :subscriber, polymorphic: true

    Notification.find_in_batches batch_size: 500 do |batch|
      batch.each do |notification|
        notification.subscriber = notification.user || notification.group
        notification.save!
      end
    end

    remove_reference :notifications, :group
    remove_reference :notifications, :user
  end
end
