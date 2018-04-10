# frozen_string_literal: true

class Kiwi::ImagePolicy < ApplicationPolicy
  def update?
    @record.package && @user.can_modify_package?(@record.package)
  end

  def destroy?
    @record.package && @user.can_modify_package?(@record.package)
  end
end
