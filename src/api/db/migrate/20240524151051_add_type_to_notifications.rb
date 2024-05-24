class AddTypeToNotifications < ActiveRecord::Migration[7.0]
  def change
    add_column :notifications, :type, :string, default: 'NotificationCommentForProject', null: false
  end
end
