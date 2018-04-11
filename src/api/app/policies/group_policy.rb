# frozen_string_literal: true

class GroupPolicy < ApplicationPolicy
  def index?
    create?
  end

  def create?
    # Only admins can create new groups atm
    @user.is_admin?
  end

  def update?
    @user.is_admin? || @record.group_maintainers.where(user: @user).exists?
  end

  def destroy?
    update?
  end
end
