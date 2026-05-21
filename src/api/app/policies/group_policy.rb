class GroupPolicy < ApplicationPolicy
  def index?
    create?
  end

  def create?
    # Only admins can create new groups atm
    user.admin?
  end

  def update?
    user.admin? || record.group_maintainers.exists?(user: user)
  end

  def destroy?
    update?
  end

  def display_email?
    !user.nobody?
  end
end
