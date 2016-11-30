#
class BsRequestActionAddRole < BsRequestAction
  #### Includes and extends
  #### Constants
  #### Self config
  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros

  #### Class methods using self. (public and then private)
  def self.sti_name
    :add_role
  end

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def check_sanity
    super
    errors.add(:role, "should not be empty for add_role") if role.blank?
    if person_name.blank? && group_name.blank?
      errors.add(:person_name, "Either person or group needs to be set")
    end
  end

  def execute_accept(_opts)
    object = Project.find_by_name(target_project)
    if target_package
      object = object.packages.find_by_name(target_package)
    end
    if person_name
      role = Role.find_by_title!(self.role)
      object.add_user( person_name, role )
    end
    if group_name
      role = Role.find_by_title!(self.role)
      object.add_group( group_name, role )
    end
    object.store(comment: "add_role request #{bs_request.number}", request: bs_request)
  end

  def render_xml_attributes(node)
    render_xml_target(node)
    if person_name
      node.person name: person_name, role: role
    end
    if group_name
      node.group name: group_name, role: role
    end
  end

  #### Alias of methods
end
