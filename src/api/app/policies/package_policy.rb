class PackagePolicy < ApplicationPolicy
  def branch?
    # same as Package.check_source_access!
    if source_access? || project_source_access?
      return false unless @user.can_source_access?(@record)
    end
    true
  end

  def update?
    @user.can_modify?(@record)
  end

  def destroy?
    @user.can_modify?(@record)
  end

  def save_meta_update?
    update? && !source_access?
  end

  def project_source_access?
    @record.project.disabled_for?('sourceaccess', nil, nil)
  end

  def source_access?
    @record.disabled_for?('sourceaccess', nil, nil)
  end
end
