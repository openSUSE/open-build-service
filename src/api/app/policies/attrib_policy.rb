class AttribPolicy < ApplicationPolicy
  def create?
    # Admins can write everything
    return true if @user.is_admin?

    # check for modifiable_by rules
    type_perms = []
    namespace_perms = []
    if @record.attrib_type
      type_perms = @record.attrib_type.attrib_type_modifiable_bies
      if @record.attrib_type.attrib_namespace
        namespace_perms = @record.attrib_type.attrib_namespace.attrib_namespace_modifiable_bies
      end
    end

    # no specific rules set for the attribute, check if the user can modify the container
    if type_perms.empty? && namespace_perms.empty? && @record.container.present?
      return @user.can_modify_project?(@record.container) if @record.container.kind_of? Project
      return @user.can_modify_package?(@record.container)
    else
      has_type_permissions?(type_perms) || has_namespace_permissions?(namespace_perms)
    end
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  private

  # Returns true when there is any permission for the user or a group or role
  # the user is associated to
  def has_type_permissions?(permissions)
    permissions.any? do |rule|
      rule.user == @user || @user.is_in_group?(rule.group) ||
        (rule.role && @user.has_local_role?(rule.role, @record.container))
    end
  end

  # Returns true when there is any permission for the user or a group the user
  # is associated to
  def has_namespace_permissions?(permissions)
    namespace_perms.any? do |rule|
      rule.user == @user || @user.is_in_group?(rule.group)
    end
  end
end
