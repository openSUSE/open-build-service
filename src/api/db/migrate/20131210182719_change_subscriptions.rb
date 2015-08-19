class ChangeSubscriptions < ActiveRecord::Migration

  class EventSubscription < ActiveRecord::Base; end

  def change
    rename_column :event_subscriptions, :receive, :receiver_role
    add_column :event_subscriptions, :receive, :boolean, null: false, default: true

    EventSubscription.where(receiver_role: 'none').each do |l|
      l.receiver_role = 'all'
      l.receive = false
      l.save
    end
  end
end
