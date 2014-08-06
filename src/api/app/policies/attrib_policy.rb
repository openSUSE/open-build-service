class AttribPolicy < ApplicationPolicy
  attr_reader :user, :attrib

  def initialize(user, attrib)
    raise Pundit::NotAuthorizedError, "Sorry, you must be signed in to perform this action." unless user
    @user = user
    @attrib = attrib
  end

  def create?
    # Admins can write everything
    return true if @user.is_admin?

    # check for modifiable_by rules
    type_perms = []
    namespace_perms = []
    if @attrib.attrib_type
      type_perms = @attrib.attrib_type.attrib_type_modifiable_bies
      if @attrib.attrib_type.attrib_namespace
        namespace_perms = @attrib.attrib_type.attrib_namespace.attrib_namespace_modifiable_bies
      end
    end
    # no specific rules set for the attribute, check if the user can modify the container
    if type_perms.empty? && namespace_perms.empty? && @attrib.container.present?
      if @attrib.container.kind_of? Project
        return @user.can_modify_project?(@attrib.container)
      else
        return @user.can_modify_package?(@attrib.container)
      end
    else
      type_perms.each do |rule|
        next if rule.user and rule.user != @user
        next if rule.group and not @user.is_in_group? rule.group
        next if rule.role and not @user.has_local_role?(rule.role, @attrib.container)
        return true
      end
      namespace_perms.each do |rule|
        next if rule.user and rule.user != @user
        next if rule.group and not @user.is_in_group? rule.group
        return true
      end
    end
    return false
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
