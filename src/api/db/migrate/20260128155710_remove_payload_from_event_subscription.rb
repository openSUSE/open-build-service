class RemovePayloadFromEventSubscription < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :event_subscriptions, :payload, :text }
  end
end
