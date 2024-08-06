class LabelTemplatePolicy < ApplicationPolicy
  def index?
    return false unless Flipper.enabled?(:labels, @user)
    return false unless record.project.maintainers.include?(@user)

    true
  end
end
