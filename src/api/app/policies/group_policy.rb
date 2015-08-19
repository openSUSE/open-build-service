class GroupPolicy < ApplicationPolicy
  attr_reader :user, :group

  def initialize(user, group)
    raise Pundit::NotAuthorizedError, "Sorry, you must be signed in to perform this action." unless user
    @user = user
    @group = group
  end

  def create?
    # Only admins can create new groups atm
    @user.is_admin?
  end

  def update?
    # is update okay at all?
    return create?  if group.nil?

    # admins can do it always
    return true if @user.is_admin?

    # and also group maintainers
    group.group_maintainers.where(user: @user).length > 0
  end

  def destroy?
    update?
  end
end
