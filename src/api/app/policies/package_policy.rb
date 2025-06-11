class PackagePolicy < ApplicationPolicy
  # FIXME: Using more than 2 arguments is considered a code smell.
  def initialize(user, record, ignore_lock: false)
    super(user, record)
    @ignore_lock = ignore_lock
  end

  def create?
    return false if !@ignore_lock && record.project.locked?
    return true if user.admin? ||
                   user.global_permission?('create_package') ||
                   user.local_permission?('create_package', record.project)

    false
  end

  def create_branch?
    source_access?
  end

  def update?
    return user.can_modify_project?(record.project) if record.name == '_project'

    user.can_modify_package?(record)
  end

  def rebuild?
    if record.readonly?
      user.can_modify_project?(record.project)
    else
      user.can_modify_package?(record)
    end
  end

  def runservice?
    rebuild?
  end

  def unlock?
    user.can_modify_package?(record, true)
  end

  def update_labels?
    user.can_modify_package?(record)
  end

  def destroy?
    user.can_modify_package?(record)
  end

  def save_meta_update?
    update? && source_access?
  end

  def source_access?
    return true if user.global_permission?(:source_access)
    return true if user.local_permission?(:source_access, record)

    record.enabled_for?('sourceaccess', nil, nil)
  end
end
