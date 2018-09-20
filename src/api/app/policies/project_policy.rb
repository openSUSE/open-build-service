class ProjectPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'record does not exist' unless record
    @user = user
    @record = record
  end

  def create?
    return false unless @user
    @user.can_create_project?(@record.name)
  end

  def update?
    return false unless @user
    return false unless local_project_and_allowed_to_create_package_in?
    # The ordering is important because of the lock status check
    return true if @user.is_admin?
    return false unless @user.can_modify?(@record, true)
    # Regular users are not allowed to modify projects with remote references
    no_remote_instance_defined_and_has_not_remote_repositories?
  end

  def destroy?
    update?
  end

  def index?
    true
  end

  def show?
    true
  end

  def unlock?
    return false unless @user
    @user.can_modify?(@record, true)
  end

  private

  def no_remote_instance_defined_and_has_not_remote_repositories?
    !@record.defines_remote_instance? && !@record.has_remote_repositories?
  end

  def local?
    @record.is_a?(Project)
  end

  def can_create_package_in?
    @user.can_create_package_in?(@record)
  end

  def local_project_and_allowed_to_create_package_in?
    local? && can_create_package_in?
  end
end
