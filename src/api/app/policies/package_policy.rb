class PackagePolicy < ApplicationPolicy
  def branch?
    # same as Package.check_source_access!
    if @record.disabled_for?('sourceaccess', nil, nil) || record.project.disabled_for?('sourceaccess', nil, nil)
      return false unless @user.can_source_access?(@record)
    end
    true
  end

  def update?
    @user.can_modify_package?(@record)
  end

  def destroy?
    @user.can_modify_package?(@record)
  end
end
