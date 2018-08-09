class AnnouncementPolicy < ApplicationPolicy
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
