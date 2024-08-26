class ChangeColumnEventPayloadFromTextToMediumtext < ActiveRecord::Migration[7.0]
  def up
    safety_assured { change_column :notifications, :event_payload, :text, limit: 16.megabytes - 1 }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
