class Staging::StagedRequestPolicy < ApplicationPolicy
  def create?
    group = record.managers_group
    user.groups_users.exists?(group: group) ||
      ProjectPolicy.new(user, record.project).update_meta?
  end

  def destroy?
    create?
  end
end
