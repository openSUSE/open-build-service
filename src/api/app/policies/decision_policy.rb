class DecisionPolicy < ApplicationPolicy
  def create?
    return false unless Flipper.enabled?(:content_moderation, user)

    user.moderator? || user.admin? || user.staff?
  end
end
