# frozen_string_literal: true
class ProjectPolicy < ApplicationPolicy
  def create?
    @user.can_create_project?(@record.name)
  end

  def update?
    # The ordering is important because of the lock status check
    return false unless @user.can_modify_project?(@record)
    return true if @user.is_admin?

    # Regular users are not allowed to modify projects with remote references
    !@record.defines_remote_instance? && !@record.has_remote_repositories?
  end

  def destroy?
    update?
  end

  def unlock?
    @user.can_modify_project?(@record, true)
  end
end
