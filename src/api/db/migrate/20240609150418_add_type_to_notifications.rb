class AddTypeToNotifications < ActiveRecord::Migration[7.0]
  def change
    add_column :notifications, :type, :string, default: 'NotificationProject', null: false
  end
end
