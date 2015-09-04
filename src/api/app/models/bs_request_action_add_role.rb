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
    return :add_role
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
    object = Project.find_by_name(self.target_project)
    if self.target_package
      object = object.packages.find_by_name(self.target_package)
    end
    if self.person_name
      role = Role.find_by_title!(self.role)
      object.add_user( self.person_name, role )
    end
    if self.group_name
      role = Role.find_by_title!(self.role)
      object.add_group( self.group_name, role )
    end
    object.store(comment: "add_role request #{self.bs_request.id}", requestid: self.bs_request.id)
  end

  def render_xml_attributes(node)
    render_xml_target(node)
    if self.person_name
      node.person name: self.person_name, role: self.role
    end
    if self.group_name
      node.group :name => self.group_name, :role => self.role
    end
  end

  #### Alias of methods

end
