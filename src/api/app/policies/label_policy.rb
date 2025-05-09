class LabelPolicy < ApplicationPolicy
  def index?
    return false unless Flipper.enabled?(:labels, user)

    true
  end

  def create?
    return false unless Flipper.enabled?(:labels, user)

    Pundit.policy!(user, record.labelable).update_labels?
  end

  def destroy?
    create?
  end

  def update?
    return false unless Flipper.enabled?(:labels, user)

    Pundit.policy!(user, record).update_labels? # record is a labelable, can be a package or a request
  end
end
