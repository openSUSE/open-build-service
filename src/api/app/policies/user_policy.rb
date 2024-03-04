class UserPolicy < ApplicationPolicy
  def update?
    user.can_modify_user?(record)
  end

  def show?
    user.can_modify_user?(record)
  end

  def check_watchlist?
    record.login == User.session!.login || User.admin_session?
  end

  def comment_index?
    record == user || user.is_staff? || user.is_moderator? || user.is_admin?
  end
end
