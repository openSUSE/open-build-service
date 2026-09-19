class DistroPolicy < ApplicationPolicy
  def create?
    VendorPolicy.new(user, record.vendor).create?
  end

  def show?
    true
  end

  def new?
    create?
  end

  def destroy?
    create?
  end

  def update?
    create?
  end
end
