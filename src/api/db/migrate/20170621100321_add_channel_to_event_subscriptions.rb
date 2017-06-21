class AddChannelToEventSubscriptions < ActiveRecord::Migration[5.0]
  def change
    add_column :event_subscriptions, :channel, :string
    EventSubscription.where(receive: false).update_all(channel: 'disabled')
    EventSubscription.where(receive: true).update_all(channel: 'instant_email')
    change_column :event_subscriptions, :channel, :string, null: false
  end
end
