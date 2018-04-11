# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def update?
    @user.can_modify_user?(@record)
  end

  def show?
    @user.can_modify_user?(@record)
  end
end
