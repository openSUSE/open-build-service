class PackageCheckUpgradePolicy < ApplicationPolicy
  
  def initialize(user, record, ignore_lock = false)
    super(user, record)
    @ignore_lock = ignore_lock
  end

  def new?
    return true if user.login
    false
  end

  def create?
    return true if user.login
    false
  end

end
