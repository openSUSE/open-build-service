class StatusMessagePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    index?
  end

  def create?
    user.is_admin? || user.is_staff?
  end

  def new?
    create?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
