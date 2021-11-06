class PackageCheckUpgradePolicy < ApplicationPolicy
  
  #FIXME add check about user

  def new?
    true
  end

  def create?
    true
  end

  def show?
    true
  end

end
