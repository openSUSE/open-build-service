class StatusMessagePolicy < ApplicationPolicy
  def create?
    user.is_admin?
  end

  def destroy?
    user.is_admin?
  end
end
