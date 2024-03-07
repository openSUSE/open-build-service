class CreateJoinTableGroupsNotifications < ActiveRecord::Migration[6.1]
  def change
    create_join_table :notifications, :groups do |t|
      t.index %i[notification_id group_id]
      t.index %i[group_id notification_id]
    end
  end
end
