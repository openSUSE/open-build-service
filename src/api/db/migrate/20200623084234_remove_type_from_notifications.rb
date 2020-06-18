class RemoveTypeFromNotifications < ActiveRecord::Migration[6.0]
  def change
    safety_assured { remove_column :notifications, :type, :string, null: false, default: '' }
  end
end
