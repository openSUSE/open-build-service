class LabelTemplateGlobalPolicy < ApplicationPolicy
  def index?
    return false unless Flipper.enabled?(:labels, user)
    return false unless user.admin?

    true
  end

  def new?
    index?
  end

  def create?
    index?
  end

  def edit?
    index?
  end

  def update?
    index?
  end

  def destroy?
    index?
  end
end
