class Staging::StagingProjectPolicy < ApplicationPolicy
  def initialize(user, record)
    super(user, record, user_optional: true)
  end

  def create?
    ProjectPolicy.new(user, record).create?
  end

  def update?
    ProjectPolicy.new(user, record).update?
  end

  def edit?
    update?
  end

  def destroy?
    ProjectPolicy.new(user, record).destroy?
  end
end
