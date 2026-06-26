class RemoveNotificationsWithoutNotifiable < ActiveRecord::Migration[6.0]
  def up
    Notification.where(notifiable_type: nil, notifiable_id: nil).destroy_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
