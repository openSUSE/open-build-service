class Staging::StagingProjectPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'staging workflow does not exist' unless record
    @user = user
    @record = record
  end

  def create?
    ProjectPolicy.new(@user, @record).create?
  end

  def update?
    ProjectPolicy.new(@user, @record).update?
  end

  def edit?
    update?
  end

  def destroy?
    ProjectPolicy.new(@user, @record).destroy?
  end
end
