class ProjectPolicy < ApplicationPolicy

  def create?
    @record.check_write_access
  end

  def update?
    # The ordering is important because of the lock status check
    return false unless @user.can_modify_project?(@record)
    return true if @user.is_admin?

    # Regular users are not allowed to modify projects with remote references
    !@record.is_remote? && !@record.has_remote_repositories?
  end

  def destroy?
    update?
  end

  def unlock?
    @user.can_modify_project?(@project, true)
  end
end
