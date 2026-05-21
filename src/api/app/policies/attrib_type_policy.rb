class AttribTypePolicy < ApplicationPolicy
  def create?
    user.admin? || access_to_type? || access_to_namespace?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  private

  def access_to_type?
    record.attrib_type_modifiable_bies.any? do |rule|
      rule.user == user || user.in_group?(rule.group)
    end
  end

  def access_to_namespace?
    record.attrib_namespace.attrib_namespace_modifiable_bies.any? do |rule|
      rule.user == user || user.in_group?(rule.group)
    end
  end
end
