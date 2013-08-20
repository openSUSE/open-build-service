class EventSubscription < ActiveRecord::Base
  belongs_to :project
  belongs_to :package
  belongs_to :user
end

class EventSubscriptionNone < EventSubscription
end

class EventSubscriptionStrictMaintainer < EventSubscription
end

class EventSubscriptionMaintainer < EventSubscription
end

class EventSubscriptionAll < EventSubscription
end
