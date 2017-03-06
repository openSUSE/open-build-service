class AttribPolicy < ApplicationPolicy
  def create?
    # Admins can write everything
    return true if @user.is_admin?

    # No specific rules set for the attribute, check if the user can modify the container
    return true if @record.container.try(:can_be_modified_by?, @user)

    # check for modifiable_by rules
    permissions_for_modifiables?(modifiables)
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  private

  # Parses AttribTypeModifiableBy and AttribNamespaceModifiableBy association
  # collections and checks the users permissions.
  #
  # Permission check is based on:
  #   - User
  #   - Group association of user
  #   - Role association of user (Only for AttribTypeModifiableBy)
  def permissions_for_modifiables?(attrib_modifiables)
    attrib_modifiables.any? do |rule|
      rule.user == @user ||
      @user.is_in_group?(rule.group) ||
        (rule.try(:role) && @user.has_local_role?(rule.role, @record.container))
    end
  end

  # Collects AttribTypeModifiableBy and AttribNamespaceModifiableBy associated to
  #  an AttribType object and returns them in an Array
  def modifiables
    @record.attrib_type.try(:attrib_type_modifiable_bies).to_a |
      @record.attrib_type.try(:attrib_namespace).try(:attrib_namespace_modifiable_bies).to_a
  end
end
