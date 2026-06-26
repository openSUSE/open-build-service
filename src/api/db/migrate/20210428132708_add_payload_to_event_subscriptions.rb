class AddPayloadToEventSubscriptions < ActiveRecord::Migration[6.0]
  def change
    add_column :event_subscriptions, :payload, :text
  end
end
