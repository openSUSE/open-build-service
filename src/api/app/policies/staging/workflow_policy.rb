class Staging::WorkflowPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'staging workflow does not exist' unless record
    @user = user
    @record = record
  end

  def create?
    ProjectPolicy.new(@user, @record.project).create?
  end

  def update?
    ProjectPolicy.new(@user, @record.project).update?
  end

  def assign_managers_group?
    update?
  end

  def edit?
    update?
  end

  def destroy?
    ProjectPolicy.new(@user, @record.project).destroy?
  end
end
