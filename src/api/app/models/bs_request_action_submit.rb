class BsRequestActionSubmit < BsRequestAction
  #### Includes and extends
  include RequestSourceDiff

  #### Constants

  #### Self config
  def self.sti_name
    return :submit
  end

  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros
  #### Class methods using self. (public and then private)
  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def is_submit?
    true
  end

  def execute_accept(opts)
    # use the request description as comments for history
    source_history_comment = self.bs_request.description

    cp_params = {
      cmd:            "copy",
      user:           User.current.login,
      oproject:       self.source_project,
      opackage:       self.source_package,
      noservice:      1,
      requestid:      self.bs_request.number,
      comment:        source_history_comment,
      withacceptinfo: 1
    }
    cp_params[:orev] = self.source_rev if self.source_rev
    cp_params[:dontupdatesource] = 1 if self.sourceupdate == "noupdate"
    unless self.updatelink
      cp_params[:expand] = 1
      cp_params[:keeplink] = 1
    end

    # create package unless it exists already
    target_project = Project.get_by_name(self.target_project)
    if self.target_package
      target_package = target_project.packages.find_by_name(self.target_package)
    else
      target_package = target_project.packages.find_by_name(self.source_package)
    end

    relinkSource=false
    unless target_package
      # check for target project attributes
      initialize_devel_package = target_project.find_attribute( "OBS", "InitializeDevelPackage" )
      # create package in database
      linked_package = target_project.find_package(self.target_package)
      if linked_package
        # exists via project links
        opts = { request: self.bs_request }
        opts[:makeoriginolder] = true if self.makeoriginolder
        instantiate_container(target_project, linked_package.update_instance, opts)
        target_package = target_project.packages.find_by_name(linked_package.name)
      else
        # new package, base container on source container
        answer = Suse::Backend.get("/source/#{URI.escape(self.source_project)}/#{URI.escape(self.source_package)}/_meta")
        newxml = Xmlhash.parse(answer.body)
        newxml['name'] = self.target_package
        newxml['devel'] = nil
        target_package = target_project.packages.new(name: newxml['name'])
        target_package.update_from_xml(newxml)
        target_package.flags.destroy_all
        target_package.remove_all_persons
        target_package.remove_all_groups
        if initialize_devel_package
          target_package.develpackage = Package.find_by_project_and_name( self.source_project, self.source_package )
          relinkSource=true
        end
        target_package.store(comment: "submit request #{self.bs_request.number}", request: self.bs_request)
      end
    end

    cp_path = "/source/#{self.target_project}/#{self.target_package}"
    cp_path << Suse::Backend.build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage,
                                                               :orev, :expand, :keeplink, :comment,
                                                               :requestid, :dontupdatesource, :noservice,
                                                               :withacceptinfo])
    result = Suse::Backend.post cp_path
    result = Xmlhash.parse(result.body)
    self.set_acceptinfo(result["acceptinfo"])

    target_package.sources_changed

    # cleanup source project
    if relinkSource and not self.sourceupdate == "noupdate"
      # source package got used as devel package, link it to the target
      # re-create it via branch , but keep current content...
      h = {}
      h[:cmd] = "branch"
      h[:user] = User.current.login
      h[:comment] = "initialized devel package after accepting #{self.bs_request.number}"
      h[:requestid] = self.bs_request.number
      h[:keepcontent] = "1"
      h[:noservice] = "1"
      h[:oproject] = self.target_project
      h[:opackage] = self.target_package
      cp_path = "/source/#{CGI.escape(self.source_project)}/#{CGI.escape(self.source_package)}"
      cp_path << Suse::Backend.build_query_from_hash(h, [:user, :comment, :cmd, :oproject, :opackage, :requestid, :keepcontent])
      Suse::Backend.post cp_path
    elsif self.sourceupdate == "cleanup"
      self.source_cleanup
    end

    if self.target_package == "_product"
      Project.find_by_name!(self.target_project).update_product_autopackages
    end
  end

  #### Alias of methods
end
