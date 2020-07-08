class AddLastSeenAtToNotifications < ActiveRecord::Migration[6.0]
  def change
    add_column :notifications, :last_seen_at, :datetime
  end
end
