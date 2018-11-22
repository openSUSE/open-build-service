class AnnouncementPolicy < ApplicationPolicy
  def initialize(user, record)
    require_user(user)
    super
  end

  def index?
    @user.is_admin?
  end

  def show?
    index?
  end

  def create?
    index?
  end

  def destroy?
    index?
  end

  def update?
    index?
  end
end
