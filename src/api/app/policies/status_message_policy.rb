class StatusMessagePolicy < ApplicationPolicy
  def create?
    user.admin? || user.staff?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  def acknowledge?
    true
  end
end
