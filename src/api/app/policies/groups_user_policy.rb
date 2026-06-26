class GroupsUserPolicy < ApplicationPolicy
  def destroy?
    # An admin, a group maintainer or the user themselves can remove themselves from a group
    user.admin? || record.group.group_maintainers.exists?(user: user) || user.id == record.user_id
  end
end
