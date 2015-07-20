class ProjectPolicy < ApplicationPolicy
  attr_reader :user, :project

  def initialize(user, project)
    @user = user
    @project = project
  end

  def save_new?
    create?
  end

  def create?
    @project.check_write_access
  end
end
