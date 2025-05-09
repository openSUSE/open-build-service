class LabelGlobalPolicy < ApplicationPolicy
  def index?
    Pundit.policy!(user, record).show? # record is a project
  end

  def create?
    update?
  end

  def destroy?
    update?
  end

  def update?
    Pundit.policy!(user, record).update? # record is a project
  end
end
