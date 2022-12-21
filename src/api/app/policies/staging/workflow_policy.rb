class Staging::WorkflowPolicy < ApplicationPolicy
  def initialize(user, record, opts = {})
    super(user, record, { ensure_logged_in: true }.merge(opts))
  end

  def new?
    create?
  end

  def create?
    ProjectPolicy.new(user, record.project).update?
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
    ProjectPolicy.new(user, record.project).destroy?
  end

  def copy?
    update?
  end

  def preview_copy?
    copy?
  end
end
