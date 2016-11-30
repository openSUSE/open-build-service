#
class BsRequestActionChangeDevel < BsRequestAction
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
    :change_devel
  end

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def execute_accept(_opts)
    target_project = Project.get_by_name(self.target_project)
    target_package = target_project.packages.find_by_name(self.target_package)
    target_package.develpackage = Package.get_by_project_and_name(source_project, source_package)

    target_package.resolve_devel_package
    target_package.store(comment: "change_devel request #{bs_request.number}", request: bs_request)
  end

  #### Alias of methods
end
