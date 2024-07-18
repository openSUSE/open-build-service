class CannedResponsePolicy < ApplicationPolicy
  def edit?
    update?
  end

  def update?
    return false unless Flipper.enabled?(:content_moderation, user)

    record.user == user
  end

  def create?
    update?
  end

  def destroy?
    update?
  end
end
