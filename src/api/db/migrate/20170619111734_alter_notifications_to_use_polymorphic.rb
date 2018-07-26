class AlterNotificationsToUsePolymorphic < ActiveRecord::Migration[5.0]
  def change
    add_column(:notifications, 'subscriber_type', :string, charset: 'utf8')
    add_column(:notifications, 'subscriber_id', :integer)
    add_index(:notifications, ['subscriber_type', 'subscriber_id'])

    # Existing notifications would fail because of incompatible payload.
    # Since this is for a feature that just got introduced we can drop them.
    Notification.delete_all

    remove_reference :notifications, :group
    remove_reference :notifications, :user
  end
end
