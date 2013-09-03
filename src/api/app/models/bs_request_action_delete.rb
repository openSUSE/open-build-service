class BsRequestActionDelete < BsRequestAction

  def self.sti_name
    return :delete
  end

  def check_sanity
    super
    errors.add(:source_project, "source can not be used in delete action") if source_project
    errors.add(:target_project, "should not be empty for #{action_type} requests") if target_project.blank?
    errors.add(:target_project, "must not target package and target repository") if target_repository and target_package
  end

  class RepositoryMissing < APIException
    setup "repository_missing", 404
  end

  def remove_repository(opts)
    prj = Project.get_by_name(self.target_project)
    r=prj.repositories.find_by_name(self.target_repository)
    unless r
      raise RepositoryMissing.new "The repository #{self.target_project} / #{self.target_repository} does not exist"
    end
    r.destroy
    prj.store(lowprio: opts[:lowprio], comment: opts[:comment])
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

    delete_path = destroy_object
    # use the request description as comments for history
    source_history_comment = self.bs_request.description
    h = {:user => User.current.login, :comment => source_history_comment, :requestid => self.bs_request.id}
    delete_path << Suse::Backend.build_query_from_hash(h, [:user, :comment, :requestid])
    Suse::Backend.delete delete_path

    if self.target_package == "_product"
      Project.find_by_name!(self.target_project).update_product_autopackages
    end

  end

  def destroy_object
    if self.target_package
      Package.get_by_project_and_name(self.target_project, self.target_package,
                                      use_source: true, follow_project_links: false).destroy
      return Package.source_path self.target_project, self.target_package
    else
      Project.get_by_name(self.target_project).destroy
      return "/source/#{self.target_project}"
    end
  end
end
