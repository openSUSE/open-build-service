require 'event_subscription'

class AddDefaultSubscriptions < ActiveRecord::Migration
  def up
    # all maintainers get all request events by default
    EventSubscription.create(eventtype: 'RequestEvent', receive: 'maintainer')
  end

  def down
    EventSubscription.delete_all
  end
end
