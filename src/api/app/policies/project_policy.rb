class ProjectPolicy < ApplicationPolicy
  def initialize(user, record)
    super(user, record, user_optional: true)
  end

  def create?
    return false unless user

    user.can_create_project?(record.name)
  end

  def update_content?
    return false unless user
    return false unless local_project_and_allowed_to_create_package_in?
    # The ordering is important because of the lock status check
    return true if user.is_admin?

    user.can_modify?(record, true)
  end

  # this check is only valid for project definition itself (project meta xml)
  def update?
    return false unless update_content?

    # Regular users are not allowed to modify project definition with remote references
    # (actually it used to be only to modify the remote references)
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
    return false unless user

    user.can_modify?(record, true)
  end

  def source_access?
    return true if user.has_global_permission?(:source_access)
    return true if user.has_local_permission?(:source_access, record)

    record.enabled_for?('sourceaccess', nil, nil)
  end

  # staging project
  def accept?
    return false unless update?

    user.run_as do
      record.staged_requests.each do |request|
        # we pretend the user asked for force, we only want to check permissions
        # not if it would makes sense to accept the request
        raise Pundit::NotAuthorizedError, query: :accept?, record: request, reason: :request_state_change unless request.permission_check_change_state(newstate: 'accepted', force: true)
      end
    end
  end

  private

  def no_remote_instance_defined_and_has_not_remote_repositories?
    !record.defines_remote_instance? && !record.has_remote_repositories?
  end

  def local?
    record.is_a?(Project)
  end

  def local_project_and_allowed_to_create_package_in?
    local? && Pundit.policy(user, Package.new(project: record)).create?
  end
end
