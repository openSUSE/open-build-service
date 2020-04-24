class AddEnabledToEventSubscription < ActiveRecord::Migration[6.0]
  def up
    safety_assured { add_column :event_subscriptions, :enabled, :boolean, default: false }
  end

  def down
    safety_assured { remove_column :event_subscriptions, :enabled, :boolean }
  end
end
