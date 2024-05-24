# frozen_string_literal: true

class BackfillNotificationsType < ActiveRecord::Migration[7.0]
  def up
    Notification.find_in_batches do |batch|
      batch.each do |notification|
        new_type = "Notification#{notification.event_type.delete_prefix('Event::')}"
        notification.update!(type: new_type)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
