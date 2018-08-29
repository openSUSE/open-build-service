class RepositoryPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'record does not exist' unless record
    @user = user
    @record = record
  end

  def create?
    update?
  end

  def update?
    ProjectPolicy.new(@user, @record.project).update?
  end

  def destroy?
    create?
  end

  def index?
    true
  end

  def show?
    index?
  end
end
