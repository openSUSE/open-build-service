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
      if @record.container.kind_of? Project
        return @user.can_modify_project?(@record.container)
      else
        return @user.can_modify_package?(@record.container)
      end
    else
      type_perms.each do |rule|
        next if rule.user && rule.user != @user
        next if rule.group && !@user.is_in_group?(rule.group)
        next if rule.role && !@user.has_local_role?(rule.role, @record.container)
        return true
      end
      namespace_perms.each do |rule|
        next if rule.user && rule.user != @user
        next if rule.group && !@user.is_in_group?(rule.group)
        return true
      end
    end
    false
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
