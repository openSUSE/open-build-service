class BsRequestActionDelete < BsRequestAction

  def self.sti_name
    return :delete
  end

  class RepositoryMissing < APIException
    setup "repository_missing", 404
  end

  def remove_repository(opts)
    prj = Project.get_by_name(self.target_project)
    r=Repository.find_by_project_and_repo_name(self.target_project, self.target_repository)
    unless r
      raise RepositoryMissing.new "The repository #{self.target_project} / #{self.target_repository} does not exist"
    end
    r.destroy
    prj.store(login: opts[:login], lowprio: opts[:lowprio], comment: opts[:comment])
  end

  def execute_changestate(opts)
    if self.target_repository
      remove_repository(opts)
    else
      if self.target_package
        package = Package.get_by_project_and_name(self.target_project, self.target_package, use_source: true, follow_project_links: false)
        package.destroy
        delete_path = "/source/#{self.target_project}/#{self.target_package}"
      else
        project = Project.get_by_name(self.target_project)
        project.destroy
        delete_path = "/source/#{self.target_project}"
      end
      # use the request description as comments for history
      source_history_comment = self.bs_request.description
      h = { :user => User.current.login, :comment => source_history_comment, :requestid => self.bs_request.id }
      delete_path << Suse::Backend.build_query_from_hash(h, [:user, :comment, :requestid])
      Suse::Backend.delete delete_path

      if self.target_package == "_product"
        Project.find_by_name!(self.target_project).update_product_autopackages
      end
      
    end
  end
end
