class FlagPolicy < ApplicationPolicy
  # just admin are able to create sourceaccess and access flags
  def create?
    user.is_admin? || ['sourceaccess', 'access'].exclude?(record.flag)
  end
end
