# frozen_string_literal: true
class AttribPolicy < ApplicationPolicy
  def create?
    # Admins can write everything
    return true if @user.is_admin?

    if @record.attrib_type.nil? || @record.attrib_type.attrib_type_modifiable_bies.empty?
      # No specific rules set for the attribute, check if the user can modify the container
      @record.container.can_be_modified_by?(@user)
    else
      # check for type modifiable_by rules
      @record.attrib_type.attrib_type_modifiable_bies.any? do |rule|
        rule.user == @user ||
          @user.is_in_group?(rule.group) ||
          (rule.try(:role) && @user.has_local_role?(rule.role, @record.container))
      end
    end
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
