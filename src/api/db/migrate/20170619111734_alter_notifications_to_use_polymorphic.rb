class AlterNotificationsToUsePolymorphic < ActiveRecord::Migration[5.0]
  def change
    add_reference :notifications, :subscriber, polymorphic: true

    # Existing notifications would fail because of incompatible payload.
    # Since this is for a feature that just got introduced we can drop them.
    Notification.delete_all

    remove_reference :notifications, :group
    remove_reference :notifications, :user
  end
end
