# frozen_string_literal: true
class AddChannelToEventSubscriptions < ActiveRecord::Migration[5.0]
  def up
    EventSubscription.transaction do
      add_column :event_subscriptions, :channel, :integer, default: 0, null: false
      EventSubscription.where(receive: true).update_all(channel: :instant_email)
    end
  end

  def down
    remove_column :event_subscriptions, :channel
  end
end
