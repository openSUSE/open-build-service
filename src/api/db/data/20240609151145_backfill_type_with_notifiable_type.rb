# frozen_string_literal: true

class BackfillTypeWithNotifiableType < ActiveRecord::Migration[7.0]
  def up
    Notification.find_in_batches do |batch|
      batch.each do |notification|
        case notification.notifiable_type
        when 'Report', 'Decision', 'Appeal'
          notification.update!(type: "NotificationReport")
        else
          notification.update!(type: "Notification#{notification.notifiable_type}")
        end
      end
    end
  end

  def down
    nil #raise ActiveRecord::IrreversibleMigration
  end
end
