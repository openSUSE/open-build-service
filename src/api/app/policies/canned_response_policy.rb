class CannedResponsePolicy < ApplicationPolicy
  def show?
    update?
  end

  def edit?
    update?
  end

  def update?
    return false unless Flipper.enabled?(:canned_responses, user)

    record.user == user
  end

  def create?
    update?
  end

  def destroy?
    update?
  end
end
