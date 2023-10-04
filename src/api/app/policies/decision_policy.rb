class DecisionPolicy < ApplicationPolicy
  def create?
    return false unless Flipper.enabled?(:content_moderation, user)

    user.is_moderator? || user.is_admin? || user.is_staff?
  end
end
