class BsRequestActionSetBugowner < BsRequestAction

  def self.sti_name
    return :set_bugowner
  end

  def check_sanity
    super
    if person_name.blank? && group_name.blank?
      errors.add(:person_name, "Either person or group needs to be set")
    end
  end

  def execute_accept(opts)
    object = Project.find_by_name!(self.target_project)
    bugowner = Role.find_by_title!("bugowner")
    if self.target_package
      object = object.packages.find_by_name!(self.target_package)
    end
    object.relationships.where("role_id = ?", bugowner).each do |r|
      r.destroy
    end
    object.add_user( self.person_name, bugowner, true ) if self.person_name # runs with ignoreLock
    object.add_group( self.group_name, bugowner, true ) if self.group_name  # runs with ignoreLock
    object.store(comment: "set_bugowner request #{self.bs_request.id}", requestid: self.bs_request.id)
  end
  
  def render_xml_attributes(node)
    render_xml_target(node)
    node.person :name => self.person_name if self.person_name
    node.group :name => self.group_name   if self.group_name
  end

end
