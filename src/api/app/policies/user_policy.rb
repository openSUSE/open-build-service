class UserPolicy < ApplicationPolicy
  def update?
    return false unless ::Configuration.accounts_editable?

    user.admin? || user == record
  end

  def destroy?
    update?
  end

  def comment_index?
    user == record || user.staff? || user.moderator? || user.admin?
  end

  def censor?
    user.admin? || user.moderator?
  end
end
