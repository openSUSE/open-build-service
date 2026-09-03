class DistroReleasePolicy < ApplicationPolicy
  def create?
    DistroPolicy.new(user, record.distro).create?
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

  def edit?
    create?
  end
end
