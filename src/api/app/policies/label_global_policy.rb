class LabelGlobalPolicy < ApplicationPolicy
  def index?
    return false unless Flipper.enabled?(:labels, user)

    Pundit.policy!(user, record).show? # record is a project
  end

  def create?
    update?
  end

  def destroy?
    update?
  end

  def update?
    return false unless Flipper.enabled?(:labels, user)

    Pundit.policy!(user, record).update? # record is a project
  end
end
