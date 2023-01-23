class GroupPolicy < ApplicationPolicy
  def index?
    create?
  end

  def create?
    # Only admins can create new groups atm
    user.is_admin?
  end

  def update?
    user.is_admin? || record.group_maintainers.exists?(user: user)
  end

  def destroy?
    update?
  end

  def display_email?
    !user.is_nobody?
  end
end
