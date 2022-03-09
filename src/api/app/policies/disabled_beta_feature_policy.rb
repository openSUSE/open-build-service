class DisabledBetaFeaturePolicy < ApplicationPolicy
  class Scope < Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, reason: ApplicationPolicy::ANONYMOUS_USER if user.nil? || user.is_nobody?

      super(user, scope)
    end

    def resolve
      scope.where(user: user)
    end
  end
end
