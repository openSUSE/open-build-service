class PackagePolicy < ApplicationPolicy
  attr_reader :user, :package

  def initialize(user, project)
    @user = user
    @package = project
  end

  def destroy?
    @user.can_modify_package?(@package) &&
      @package.can_be_deleted?
  end
end
