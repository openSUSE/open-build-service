class StatusMessagePolicy < ApplicationPolicy
  def create?
    user.is_admin?
  end

  def destroy?
    user.is_admin?
  end

  def index?
    user.is_admin?
  end

  def show?
    user.is_admin?
  end
end
