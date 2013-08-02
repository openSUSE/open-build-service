class BsRequestActionSetBugowner < BsRequestAction

  def self.sti_name
    return :set_bugowner
  end

  def execute_changestate(opts)
    object = Project.find_by_name!(self.target_project)
    bugowner = Role.get_by_title("bugowner")
    if self.target_package
      object = object.packages.find_by_name!(self.target_package)
    end
    object.relationships.where("role_id = ?", bugowner).each do |r|
      r.destroy
    end
    object.add_user( self.person_name, bugowner )
    object.store
  end
  
  def render_xml_attributes(node)
    render_xml_target(node)
    node.person :name => self.person_name
  end

end
