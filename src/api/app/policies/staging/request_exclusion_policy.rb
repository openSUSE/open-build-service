class Staging::RequestExclusionPolicy < ApplicationPolicy
  def create?
    group = record.staging_workflow.managers_group
    user.groups_users.where(group: group).exists? ||
      ProjectPolicy.new(user, record.staging_workflow.project).update?
  end

  def destroy?
    create?
  end
end
