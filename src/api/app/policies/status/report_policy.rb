class Status::ReportPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'record does not exist' unless record
    @user = user
    @record = record
  end

  def create?
    return false if @user.blank?
    @record.projects && @record.projects.all? { |project| @user.can_modify?(project) }
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  def index?
    true
  end

  def show?
    true
  end
end
