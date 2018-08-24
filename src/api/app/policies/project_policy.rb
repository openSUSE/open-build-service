class ProjectPolicy < ApplicationPolicy
  def create?
    @user.can_create_project?(@record.name)
  end

  def update?
    update_or_delete
  end

  def destroy?
    update_or_delete
  end

  def delete?
    update_or_delete
  end

  def unlock?
    @user.can_modify?(@record, true)
  end

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

  def update_or_delete
    return false unless local_project_and_allowed_to_create_package_in?
    # The ordering is important because of the lock status check
    return true if @user.is_admin?
    return false unless @user.can_modify?(@record, true)
    # Regular users are not allowed to modify projects with remote references
    no_remote_instance_defined_and_has_not_remote_repositories?
  end
end
