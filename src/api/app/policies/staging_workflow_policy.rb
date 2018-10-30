class StagingWorkflowPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'staging workflow does not exist' unless record
    @user = user
    @record = record
  end

  def create?
    ProjectPolicy.new(@user, @record.project).create?
  end
end
