class NotificationPolicy < ApplicationPolicy
  class Scope < Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, reason: ApplicationPolicy::ANONYMOUS_USER if user.nil? || user.is_nobody?

      super(user, scope)
    end

    def resolve
      NotificationsFinder.new(scope).for_subscribed_user(user)
    end
  end
end
