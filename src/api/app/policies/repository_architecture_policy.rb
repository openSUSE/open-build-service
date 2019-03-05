class RepositoryArchitecturePolicy < ApplicationPolicy
  def initialize(user, record)
    super(user, record, user_optional: true)
  end

  def create?
    update?
  end

  def update?
    RepositoryPolicy.new(user, record.repository).update?
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
