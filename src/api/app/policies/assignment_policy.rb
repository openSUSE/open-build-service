# Only package or project collaborators (and Admin) can assign people.
# We are only checking the assigner here. Who can you assign as assignee is
# checked as Assignment model validation.
class AssignmentPolicy < ApplicationPolicy
  def create?
    return false unless Flipper.enabled?(:foster_collaboration, user)
    return true if user.admin?
    return true if record.package.relationships.joins(:role).where(roles: { title: %w[maintainer bugowner reviewer] }).where(user_id: user).any?

    record.package.project.relationships.joins(:role).where(roles: { title: %w[maintainer bugowner reviewer] }).where(user_id: user).any?
  end

  def destroy?
    create?
  end
end
