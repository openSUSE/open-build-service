# frozen_string_literal: true

class AttribNamespacePolicy < ApplicationPolicy
  def create?
    @user.is_admin? || access_to_namespace?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  private

  def access_to_namespace?
    @record.attrib_namespace_modifiable_bies.any? do |rule|
      rule.user == @user || @user.is_in_group?(rule.group)
    end
  end
end
