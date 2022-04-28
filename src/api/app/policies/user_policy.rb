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
end
