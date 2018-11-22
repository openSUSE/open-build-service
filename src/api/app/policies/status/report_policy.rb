class Status::ReportPolicy < ApplicationPolicy
  def initialize(user, record)
    require_record(record)
    @user = user
    @record = record
  end

  def create?
    require_user(user)
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
