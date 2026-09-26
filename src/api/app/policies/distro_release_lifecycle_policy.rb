class DistroReleaseLifecyclePolicy < ApplicationPolicy
  def create?
    DistroReleasePolicy.new(user, record.distro_release).create?
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
