# frozen_string_literal: true

class ReEncodeEventPayloads < ActiveRecord::Migration[5.1]
  def up
    # Re-encode the events that creates notifications for using only one encoder (ActiveSupport::JSON)
    Event::Base.notification_events.each do |event_type|
      event_type.where(mails_sent: false).find_in_batches do |batch|
        batch.each do |event|
          event.set_payload(event.payload, event.payload_keys)
          event.save!
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
