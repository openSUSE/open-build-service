# frozen_string_literal: true

class DeleteOrphanRecordsFromNotifiedProject < ActiveRecord::Migration[7.2]
  def up
    say_with_time 'Removing orphaned records from notified projects' do
      NotifiedProject.where.not(notification_id: Notification.select(:id)).delete_all
    end
  end

  def down; end
end
