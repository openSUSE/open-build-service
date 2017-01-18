class GroupPolicy < ApplicationPolicy
  def index?
    create?
  end

  def create?
    # Only admins can create new groups atm
    @user.is_admin?
  end

  def update?
    # admins can do it always
    return true if @user.is_admin?

    # and also group maintainers
    !@record.group_maintainers.where(user: @user).empty?
  end

  def destroy?
    update?
  end
end
