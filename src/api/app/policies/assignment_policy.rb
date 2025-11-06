# Only package or project collaborators (and Admin) can assign people.
# We are only checking the assigner here. Who can you assign as assignee is
# checked as Assignment model validation.
class AssignmentPolicy < ApplicationPolicy
  def create?
    return false unless Flipper.enabled?(:foster_collaboration, user)
    return true if user.admin?

    roles = Role.where(title: %w[maintainer bugowner reviewer])
    (record.package.relationships.where(role_id: roles.ids, user_id: user) + record.package.project.relationships.where(role_id: roles.ids, user_id: user)).any?
  end

  def destroy?
    create?
  end
end
