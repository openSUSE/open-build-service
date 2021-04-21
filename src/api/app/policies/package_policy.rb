class PackagePolicy < ApplicationPolicy
  # FIXME: Using more than 2 arguments is considered a code smell.
  def initialize(user, record, ignore_lock = false)
    super(user, record)
    @ignore_lock = ignore_lock
  end

  def create?
    return false if !@ignore_lock && record.project.is_locked?
    return true if user.is_admin? ||
                   user.has_global_permission?('create_package') ||
                   user.has_local_permission?('create_package', record.project)

    false
  end

  def create_branch?
    # same as Package.check_source_access!
    if source_access? || project_source_access?
      return false unless user.can_source_access?(record)
    end
    true
  end

  def update?
    user.can_modify?(record)
  end

  def destroy?
    user.can_modify?(record)
  end

  def save_meta_update?
    update? && !source_access?
  end

  def project_source_access?
    record.project.disabled_for?('sourceaccess', nil, nil)
  end

  def source_access?
    record.disabled_for?('sourceaccess', nil, nil)
  end
end
