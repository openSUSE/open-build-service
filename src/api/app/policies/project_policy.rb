class ProjectPolicy < ApplicationPolicy
  attr_reader :user, :project

  def initialize(user, project)
    @user = user
    @project = project
  end

  def create?
    @project.check_write_access
  end

  def update?
    # The ordering is important because of the lock status check
    return false unless @user.can_modify_project?(@project)
    return true if @user.is_admin?

    # Regular users are not allowed to modify projects with remote references
    !@project.is_remote? && !@project.has_remote_repositories?
  end

  def destroy?
    update?
  end
end
