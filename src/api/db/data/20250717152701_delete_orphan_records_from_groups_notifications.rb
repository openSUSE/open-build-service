# frozen_string_literal: true

class GroupsNotification < ActiveRecord::Base
  self.table_name = 'groups_notifications'
end

class DeleteOrphanRecordsFromGroupsNotifications < ActiveRecord::Migration[7.2]
  def up
    say_with_time 'Removing orphaned records from groups_notifications' do
      GroupsNotification.where.not(notification_id: Notification.select(:id)).delete_all
    end
  end

  def down; end
end
