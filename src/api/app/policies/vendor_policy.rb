class VendorPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def show?
    true
  end

  def create?
    ProjectPolicy.new(user, record.project).update?
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
