class ChangeNotificationIdToUnsigned < ActiveRecord::Migration[6.0]
  def up
    safety_assured { change_column :notifications, :id, :int, null: false, unique: true, auto_increment: true, unsigned: true }
  end

  def down
    safety_assured { change_column :notifications, :id, :int, null: false, unique: true, auto_increment: true, unsigned: false }
  end
end
