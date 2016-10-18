#
class BsRequestActionDelete < BsRequestAction
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
    return :delete
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  def check_sanity
    super
    errors.add(:source_project, "source can not be used in delete action") if source_project
    errors.add(:target_project, "should not be empty for #{action_type} requests") if target_project.blank?
    errors.add(:target_project, "must not target package and target repository") if target_repository && target_package
  end

  def remove_repository(opts)
    prj = Project.get_by_name(self.target_project)
    r=prj.repositories.find_by_name(self.target_repository)
    unless r
      raise RepositoryMissing.new "The repository #{self.target_project} / #{self.target_repository} does not exist"
    end
    r.destroy
    prj.store(lowprio: opts[:lowprio], comment: opts[:comment], request: self.bs_request)
  end

  def render_xml_attributes(node)
    attributes = xml_package_attributes('target')
    attributes[:repository] = self.target_repository unless self.target_repository.blank?
    node.target attributes
  end

  def sourcediff(opts = {})
    if self.target_package
      path = Package.source_path self.target_project, self.target_package
      query = {'cmd' => 'diff', expand: 1, filelimit: 0, rev: 0}
      query[:view] = 'xml' if opts[:view] == 'xml' # Request unified diff in full XML view
      return BsRequestAction.get_package_diff(path, query)
    elsif self.target_repository
      # no source diff
    else
      raise DiffError.new("Project diff isn't implemented yet")
    end
    return ''
  end

  def execute_accept(opts)
    if self.target_repository
      remove_repository(opts)
      return
    end

    if self.target_package
      package = Package.get_by_project_and_name(self.target_project, self.target_package,
                                                use_source: true, follow_project_links: false)
      package.commit_opts = { comment: self.bs_request.description, request: self.bs_request }
      package.destroy
      return Package.source_path self.target_project, self.target_package
    else
      project = Project.get_by_name(self.target_project)
      project.commit_opts = { comment: self.bs_request.description, request: self.bs_request }
      project.destroy
      return "/source/#{self.target_project}"
    end
  end

  #### Alias of methods
end
