class PackagePolicy < ApplicationPolicy
  attr_reader :user, :package

  def initialize(user, package)
    @user = user
    @package = package
  end

  def delete?
    @user.can_modify_package?(@package)
  end
end
