class Status::CheckPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'record does not exist' unless record
    @user = user
    @record = record
  end

  def create?
    return false if @user.blank?
    @user.is_admin? ||
      @record.checkable.relationships.users.pluck(:user_id).include?(@user.id) ||
      @record.checkable.groups_users.pluck(:user_id).include?(@user.id)
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
    index?
  end
end
