class BsRequestActionChangeDevel < BsRequestAction

  def self.sti_name
    return :change_devel
  end

  def execute_changestate(opts)
    target_project = Project.get_by_name(self.target_project)
    target_package = target_project.packages.find_by_name(self.target_package)
    target_package.develpackage = Package.get_by_project_and_name(self.source_project, self.source_package)
    
    target_package.resolve_devel_package
    target_package.store
  end
end
