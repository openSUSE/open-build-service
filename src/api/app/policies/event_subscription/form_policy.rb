class EventSubscription
  class FormPolicy < ApplicationPolicy
    def update?
      user == record.subscriber
    end
  end
end
