class UserPolicy < ApplicationPolicy
  def update?
    return false unless ::Configuration.accounts_editable?(@user)

    user.is_admin? || user == record
  end

  def destroy?
    update?
  end

  def comment_index?
    user == record || user.is_staff? || user.is_moderator? || user.is_admin?
  end

  def block_commenting?
    user.is_admin? || user.is_moderator?
  end
end
