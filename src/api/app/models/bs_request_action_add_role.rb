class BsRequestActionAddRole < BsRequestAction

  def self.sti_name
    return :add_role
  end

  def check_sanity
    super
    errors.add(:role, "should not be empty for add_role") if role.blank?
    if person_name.blank? && group_name.blank?
      errors.add(:person_name, "Either person or group needs to be set")
    end
  end

  def execute_accept(opts)
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
    object.store
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
end
