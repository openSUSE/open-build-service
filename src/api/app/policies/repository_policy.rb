class RepositoryPolicy < ApplicationPolicy
  def initialize(user, record)
    super(user, record, user_optional: true)
  end

  def create?
    update?
  end

  def update?
    ProjectPolicy.new(user, record.project).update?
  end

  def destroy?
    create?
  end

  def index?
    true
  end

  def show?
    index?
  end
end
