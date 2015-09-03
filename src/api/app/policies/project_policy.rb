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
    @user.can_modify_project?(@project) &&
        !@project.is_remote? &&
        !@project.has_remote_repositories?
  end

  def destroy?
    update?
  end
end
