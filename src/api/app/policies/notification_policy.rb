class NotificationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      NotificationsFinder.new(scope).for_subscribed_user(user)
    end
  end
end
