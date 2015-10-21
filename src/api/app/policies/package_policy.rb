class PackagePolicy < ApplicationPolicy

  def update?
    @user.can_modify_package?(@record)
  end

  def destroy?
    @user.can_modify_package?(@record)
  end
end
