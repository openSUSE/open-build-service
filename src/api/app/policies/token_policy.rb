class TokenPolicy < ApplicationPolicy
  def create?
    return true if user.admin?
    return false unless user.confirmed?

    record.executor == user
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
