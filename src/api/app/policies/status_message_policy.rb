class StatusMessagePolicy < ApplicationPolicy
  def create?
    user.is_admin? || user.is_staff?
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
