class Staging::WorkflowPolicy < ApplicationPolicy
  def new?
    create?
  end

  def create?
    update?
  end

  def update?
    ProjectPolicy.new(user, record.project).update?
  end

  def assign_managers_group?
    update?
  end

  def edit?
    update?
  end

  def destroy?
    update?
  end

  def copy?
    update?
  end

  def preview_copy?
    copy?
  end
end
