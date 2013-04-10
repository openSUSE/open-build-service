class BsRequestActionSetBugowner < BsRequestAction

  def self.sti_name
    return :set_bugowner
  end

  def execute_changestate(opts)
    object = Project.find_by_name!(self.target_project)
    bugowner = Role.get_by_title("bugowner")
    if self.target_package
      object = object.packages.find_by_name!(self.target_package)
      PackageUserRoleRelationship.where("db_package_id = ? AND role_id = ?", object, bugowner).each do |r|
        r.destroy
      end
    else
      ProjectUserRoleRelationship.where("db_project_id = ? AND role_id = ?", object, bugowner).each do |r|
        r.destroy
      end
    end
    object.add_user( self.person_name, bugowner )
    object.store
  end

end
