class BlockedUserPolicy < ApplicationPolicy
  def create?
    return false unless Flipper.enabled?(:content_moderation, user)
    return false if record.blocked == user

    true
  end

  def destroy?
    return false unless Flipper.enabled?(:content_moderation, user)
    return false if record.blocked == user

    true
  end
end
