class ChangeNotificationsPrimaryAndForeignKeysToBigint < ActiveRecord::Migration[7.0]
  def up
    # This migration blocks the table, we are running it during Maintenance Window.
    safety_assured do
      # Foreign key
      change_column :notified_projects, :notification_id, :bigint
      # Primary key
      change_column :notified_projects, :id, :bigint, auto_increment: true
      change_column :notifications, :id, :bigint, auto_increment: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
