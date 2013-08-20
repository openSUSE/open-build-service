require 'event_subscription'

class AddDefaultSubscriptions < ActiveRecord::Migration
  def up
    # all maintainers get all request events by default
    EventSubscriptionMaintainer.create(eventtype: 'RequestEvent')
  end

  def down
    EventSubscription.delete_all
  end
end
