# frozen_string_literal: true

class BackfillTypeOfRelationshipNotifications < ActiveRecord::Migration[7.0]
  def up
    Notification.where(type: nil, event_type: ['Event::RelationshipCreate', 'Event::RelationshipDelete']).in_batches do |batch|
      batch.find_each do |notification|
        notification.update(type: "Notification#{notification.notifiable_type}")
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
