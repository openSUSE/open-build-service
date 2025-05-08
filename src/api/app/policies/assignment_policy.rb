# Only package or project collaborators (and Admin) can assign people.
# We are only checking the assigner here. Who can you assign as assignee is
# checked as Assignment model validation.
class AssignmentPolicy < ApplicationPolicy
  def create?
    return false unless Flipper.enabled?(:foster_collaboration, user)

    return true if user.admin?

    record.assignee_is_a_collaborator
  end

  def destroy?
    create?
  end
end
