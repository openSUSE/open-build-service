class LabelPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    Pundit.policy!(user, record.labelable).update_labels?
  end

  def destroy?
    create?
  end

  def update?
    Pundit.policy!(user, record).update_labels? # record is a labelable, can be a package or a request
  end
end
