class ChangeNotificationEventPayloadToMediumtext < ActiveRecord::Migration[7.0]
  def up
    safety_assured { change_column :notifications, :event_payload, :mediumtext }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
