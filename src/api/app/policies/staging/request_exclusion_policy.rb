class Staging::RequestExclusionPolicy < ApplicationPolicy
  def create?
    group = record.managers_group
    user.groups_users.where(group: group).exists? ||
      ProjectPolicy.new(user, record.project).update?
  end

  def destroy?
    create?
  end
end
