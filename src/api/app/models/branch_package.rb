class BranchPackage
  class InvalidArgument < APIException; end
  class InvalidFilelistError < APIException; end
  class DoubleBranchPackageError < APIException; end

  attr_accessor :params

  # generic branch function for package based, project wide or request based branch
  def initialize(params)
    self.params = params

    # set defaults
    @attribute = params[:attribute] || 'OBS:Maintained'
    @target_project = nil
    @auto_cleanup = nil
    @add_repositories = params[:add_repositories]
    # check if repository path elements do use each other and adapt our own path elements
    @update_path_elements = params[:update_path_elements]
    # create hidden project ?
    @noaccess = params[:noaccess]
    # extend repo and package names ?
    @extend_names = params[:extend_package_names]
    @rebuild_policy = params[:add_repositories_rebuild]
    @block_policy = params[:add_repositories_block]
    raise InvalidArgument.new unless [nil, "all", "local", "never"].include? @block_policy
    raise InvalidArgument.new unless [nil, "transitive", "direct", "local"].include? @rebuild_policy
    # copy from devel package instead branching ?
    @copy_from_devel = false
    @copy_from_devel = true if params[:newinstance]
    # explicit asked for maintenance branch ?
    if params[:maintenance]
      @extend_names = true
      @copy_from_devel = true
      @add_repositories = true
      @update_path_elements = true
    end
  end

  def logger
    Rails.logger
  end

  def branch
    #
    # 1) BaseProject <-- 2) UpdateProject <-- 3) DevelProject/Package
    # X) BranchProject
    #
    # 2/3) are optional
    #
    # X) is target_project with target_package, the project where new sources get created
    #
    # link_target_project points to 3) or to 2) in copy_from_devel case
    #
    # name of 1) may get used in package or repo names when using :extend_name
    #

    set_target_project

    set_update_project_attribute

    find_packages_to_branch

    # lookup update project, devel project or local linked packages.
    # Just requests should be nearly the same
    find_package_targets unless params[:request]

    @target_project ||= User.current.branch_project_name(params[:project])

    #
    # Data collection complete at this stage
    #

    # Just report the result in dryrun, but not action
    if params[:dryrun]
      # dry run, just report the result, but no effect
      return { text: report_dryrun, content_type: 'text/xml' }
    end

    # create branch project
    tprj = create_branch_project

    unless User.current.can_modify_project?(tprj)
      raise Project::WritePermissionError.new "no permission to modify project '#{@target_project}' while executing branch project command"
    end

    # all that worked ? :)
    return { data: create_branch_packages(tprj) }
  end

  def create_branch_packages(tprj)
    # collect also the needed repositories here
    response = nil
    @packages.each do |p|
      pac = p[:package]

      # find origin package to be branched
      branch_target_package = p[:target_package]
      pack_name = branch_target_package.tr(':', '_')

      # create branch package
      # no find_package call here to check really this project only
      tpkg = tprj.packages.find_by_name(pack_name)
      if tpkg
        unless params[:force]
          raise DoubleBranchPackageError.new "branch target package already exists: #{tprj.name}/#{tpkg.name}"
        end
      else
        if pac.is_a? Package
          tpkg = tprj.packages.new(name: pack_name, title: pac.title, description: pac.description)
          tpkg.bcntsynctag = pac.bcntsynctag
        else
          tpkg = tprj.packages.new(name: pack_name)
        end
        if tpkg.bcntsynctag && @extend_names
          tpkg.bcntsynctag << '.' + p[:link_target_project].name.tr(':', '_')
        end
        tpkg.releasename = p[:release_name]
        tprj.packages << tpkg
      end
      tpkg.store

      if p[:local_link]
        # rubocop:disable Metrics/LineLength
        # copy project local linked packages
        Suse::Backend.post "/source/#{tpkg.project.name}/#{tpkg.name}?cmd=copy&oproject=#{CGI.escape(p[:link_target_project].name)}&opackage=#{CGI.escape(p[:package].name)}&user=#{CGI.escape(User.current.login)}"
        # rubocop:enable Metrics/LineLength
        # and fix the link
        ret = ActiveXML::Node.new(tpkg.source_file('_link'))
        ret.delete_attribute('project') # its a local link, project name not needed
        linked_package = p[:link_target_package]
         # user enforce a rename of base package
        linked_package = params[:target_package] if params[:target_package] && params[:package] == ret.value('package')
        linked_package += '.' + p[:link_target_project].name.tr(':', '_') if @extend_names
        ret.set_attribute('package', linked_package)
        Suse::Backend.put tpkg.source_path('_link', user: User.current.login), ret.dump_xml
      else
        opackage = p[:package]
        opackage = p[:package].name if p[:package].is_a? Package
        oproject = p[:link_target_project]
        oproject = p[:link_target_project].name if p[:link_target_project].is_a? Project

        # branch sources in backend
        tpkg.branch_from(oproject, opackage, p[:rev], params[:missingok], nil, params[:linkrev])
        if response
          # multiple package transfers, just tell the target project
          response = { targetproject: tpkg.project.name }
        else
          # just a single package transfer, detailed answer
          response = { targetproject: tpkg.project.name, targetpackage: tpkg.name, sourceproject: oproject, sourcepackage: opackage }
        end

        # fetch newer sources from devel package, if defined
        if p[:copy_from_devel] && p[:copy_from_devel].project != tpkg.project && !p[:rev]
          if p[:copy_from_devel].project.is_maintenance_incident?
            msg="fetch+updates+from+open+incident+project+#{CGI.escape(p[:copy_from_devel].project.name)}"
          else
            msg="fetch+updates+from+devel+package+#{CGI.escape(p[:copy_from_devel].project.name)}/#{CGI.escape(p[:copy_from_devel].name)}"
          end
          # TODO: make this a query hash
          # rubocop:disable Metrics/LineLength
          Suse::Backend.post tpkg.source_path + "?cmd=copy&keeplink=1&expand=1&oproject=#{CGI.escape(p[:copy_from_devel].project.name)}&opackage=#{CGI.escape(p[:copy_from_devel].name)}&user=#{CGI.escape(User.current.login)}&comment=#{msg}"
          # rubocop:enable Metrics/LineLength
        end
      end
      tpkg.sources_changed

      # create repositories, if missing
      if @add_repositories
        # rubocop:disable Style/EmptyElse
        if p[:link_target_project].is_a? Project
          opts = {}
          opts[:extend_names] = true if @extend_names
          opts[:rebuild] = @rebuild_policy if @rebuild_policy
          opts[:block]   = @block_policy   if @block_policy
          tprj.branch_to_repositories_from(p[:link_target_project], tpkg, opts)
        else
          # FIXME: for remote project instances
          # Please also remove the rubocop ignore comment when you implement the FIXME
        end
        # rubocop:enable Style/EmptyElse
      end

      if tprj.is_maintenance_incident?
        tpkg.add_channels
      end
    end
    tprj.sync_repository_pathes if @update_path_elements

    # store project data in DB and XML
    tprj.store
    response
  end

  def create_branch_project
    if Project.exists_by_name @target_project
      if @noaccess
        raise CreateProjectNoPermission.new "The destination project already exists, so the api can't make it not readable"
      end
      tprj = Project.get_by_name @target_project
    else
      # permission check
      unless User.current.can_create_project?(@target_project)
        raise CreateProjectNoPermission.new "no permission to create project '#{@target_project}' while executing branch command"
      end

      title = "Branch project for package #{params[:package]}"
      description = "This project was created for package #{params[:package]} via attribute #{@attribute}"
      if params[:request]
        title = "Branch project based on request #{params[:request]}"
        description = "This project was created as a clone of request #{params[:request]}"
      end
      @add_repositories = true # new projects shall get repositories
      Project.transaction do
        tprj = Project.create name: @target_project, title: title, description: description
        tprj.relationships.build(user: User.current, role: Role.find_by_title!('maintainer'))
        tprj.flags.create(flag: 'build', status: 'disable') if @extend_names
        tprj.flags.create(flag: 'access', status: 'disable') if @noaccess
        tprj.store
        add_autocleanup_attribute(tprj) if @auto_cleanup
      end
      if params[:request]
        ans = AttribNamespace.find_by_name 'OBS'
        at = ans.attrib_types.find_by(name: 'RequestCloned')

        tprj = Project.get_by_name @target_project
        a = Attrib.new(project: tprj, attrib_type: at)
        a.values << AttribValue.new(value: params[:request], position: 1)
        a.save
      end
    end
    tprj
  end

  def add_autocleanup_attribute(tprj)
    at = AttribType.find_by_namespace_and_name!('OBS', 'AutoCleanup')
    a = Attrib.new(project: tprj, attrib_type: at)
    a.values << AttribValue.new(value: (DateTime.now + @auto_cleanup.days), position: 1)
    a.save
  end

  def report_dryrun
    @packages.sort! { |x, y| x[:target_package] <=> y[:target_package] }
    builder = Builder::XmlMarkup.new(indent: 2)
    builder.collection do
      @packages.each do |p|
        if p[:package].is_a? Package
          builder.package(project: p[:link_target_project].name, package: p[:package].name) do
            builder.devel(project: p[:copy_from_devel].project.name, package: p[:copy_from_devel].name) if p[:copy_from_devel]
            builder.target(project: @target_project, package: p[:target_package])
          end
        else
          builder.package(project: p[:link_target_project], package: p[:package]) do
            builder.devel(project: p[:copy_from_devel].project.name, package: p[:copy_from_devel].name) if p[:copy_from_devel]
            builder.target(project: @target_project, package: p[:target_package])
          end
        end
      end
    end
  end

  def find_package_targets
    @packages.each do |p|
      determine_details_about_package_to_branch(p)
    end

    @packages.each { |p| extend_packages_to_link(p) }

    # avoid double hits eg, when the same update project is used by multiple GA projects
    seen={}
    @packages.each do |p|
      @packages.delete(p) if seen[p[:package]]
      seen[p[:package]]=true
    end
  end

  def lookup_incident_pkg(p)
    return nil unless p[:package].kind_of? Package
    @obs_maintenanceproject ||= AttribType.find_by_namespace_and_name!('OBS', 'MaintenanceProject')
    @maintenanceProjects ||= Project.find_by_attribute_type(@obs_maintenanceproject)
    incident_pkg=nil
    p[:link_target_project].maintenance_projects.each do |mp|
      # no defined devel area or no package inside, but we branch from a release are: check in open incidents

      # only approved maintenance projects
      next unless @maintenanceProjects.include? mp.maintenance_project

      # rubocop:disable Metrics/LineLength
      path = "/search/package/id?match=(linkinfo/@package=\"#{CGI.escape(p[:package].name)}\"+and+linkinfo/@project=\"#{CGI.escape(p[:link_target_project].name)}\""
      # rubocop:enable Metrics/LineLength
      path += "+and+starts-with(@project,\"#{CGI.escape(mp.maintenance_project.name)}%3A\"))"
      answer = Suse::Backend.post path
      data = REXML::Document.new(answer.body)
      data.elements.each('collection/package') do |e|
        ipkg = Package.find_by_project_and_name(e.attributes['project'], e.attributes['name'])
        if ipkg.nil?
          logger.error "read permission or data inconsistency, backend delivered package " +
                       "as linked package where no database object exists: #{e.attributes['project']} / #{e.attributes['name']}"
        else
          # is incident ?
          if ipkg.project.is_maintenance_incident? && ipkg.project.is_unreleased?
            # is a newer incident ?
            if incident_pkg.nil? || ipkg.project.name.gsub(/.*:/, '').to_i > incident_pkg.project.name.gsub(/.*:/, '').to_i
              incident_pkg = ipkg
            end
          end
        end
      end
    end
    # newest incident pkg or nil
    incident_pkg
  end

  def determine_details_about_package_to_branch(p)
    return unless p[:link_target_project].is_a? Project # only for local source projects

    check_for_update_project(p) unless params[:ignoredevel]

    if params[:newinstance]
      p[:link_target_project] = Project.get_by_name params[:project]
      p[:target_package] = p[:package].name
      p[:target_package] += ".#{p[:link_target_project].name}" if @extend_names
    end
    if @extend_names
      p[:release_name] = p[:package].kind_of?(String) ? p[:package] : p[:package].name
    end

    # validate and resolve devel package or devel project definitions
    unless params[:ignoredevel] || p[:copy_from_devel]

      devel_package = p[:package].find_devel_package if p[:package].is_a? Package
      if @copy_from_devel && devel_package
        p[:copy_from_devel] = devel_package
        logger.info "sources will get copied from devel package #{devel_package.project.name}/#{devel_package.name}"
      else
        incident_pkg = lookup_incident_pkg(p)
        if incident_pkg
          p[:copy_from_devel] = incident_pkg
          logger.info "sources will get copied from incident package #{incident_pkg.project.name}/#{incident_pkg.name}"
        elsif !@copy_from_devel && devel_package
          p[:package] = devel_package
          p[:link_target_project] = p[:package].project unless params[:newinstance]
          p[:target_package] = p[:package].name
          p[:target_package] += ".#{p[:link_target_project].name}" if @extend_names
          # user specified target name
          p[:target_package] = params[:target_package] if params[:target_package]
          logger.info "devel project is #{p[:link_target_project].name} #{p[:package].name}"
        end
      end
    end

    # set default based on first found package location
    unless @target_project
      @target_project = User.current.branch_project_name(p[:link_target_project])
      @auto_cleanup = ::Configuration.cleanup_after_days
      set_image_template_configuration(p[:base_project])
    end

    # link against srcmd5 instead of plain revision
    expand_rev_to_srcmd5(p) if p[:rev]
  end

  def set_image_template_configuration(project)
    if project.try(:image_template?)
      @auto_cleanup ||= 14
      @rebuild_policy ||= "local"
    end
  end

  def expand_rev_to_srcmd5(p)
    dir = Directory.find(project: params[:project], package: params[:package], rev: params[:rev])
    raise InvalidFilelistError.new 'no such revision' unless dir
    p[:rev] = dir.value(:srcmd5)
    unless p[:rev]
      raise InvalidFilelistError.new 'no srcmd5 revision found'
    end
  end

  def check_for_update_project(p)
    pkg = p[:package]
    prj = p[:link_target_project]
    if pkg.is_a? Package
      logger.debug "Check Package #{p[:package].project.name}/#{p[:package].name}"
      prj = pkg.project
      pkg_name = pkg.name
    else
      pkg_name = pkg
      logger.debug "Check package string #{pkg}"
    end
    # Check for defined update project
    update_project = update_project_for_project(prj)
    return unless update_project

    pa = update_project.packages.find_by(name: pkg_name)
    if pa
      # We have a package in the update project already, take that
      p[:package] = pa
      unless p[:link_target_project].is_a?(Project) && p[:link_target_project].find_attribute('OBS', 'BranchTarget')
        p[:link_target_project] = pa.project
        logger.info "branch call found package in update project #{pa.project.name}"
      end
      if p[:link_target_project].find_package(pa.name) != pa
        # our link target has no project link finding the package.
        # It got found via update project for example, so we need to use it's source
        p[:copy_from_devel] = p[:package]
      end
    else
      unless p[:link_target_project].is_a?(Project) && p[:link_target_project].find_attribute('OBS', 'BranchTarget')
        p[:link_target_project] = update_project
      end
      update_pkg = update_project.find_package(pkg_name, true) # true for check_update_package in older service pack projects
      if update_pkg
        # We have no package in the update project yet, but sources are reachable via project link
        up = update_project.develproject.find_package(pkg_name) if update_project.develproject
        if defined?(up) && up
          # nevertheless, check if update project has a devel project which contains an instance
          p[:package] = up
          unless p[:link_target_project].is_a?(Project) && p[:link_target_project].find_attribute('OBS', 'BranchTarget')
            p[:link_target_project] = up.project unless @copy_from_devel
          end
          logger.info "link target will create package in update project #{up.project.name} for #{prj.name}"
        else
          logger.info "link target will use old update in update project #{prj.name}"
        end
      else
        # The defined update project can't reach the package instance at all.
        # So we need to create a new package and copy sources
        params[:missingok] = 1 # implicit missingok or better report an error ?
        p[:copy_from_devel] = p[:package].find_devel_package if p[:package].is_a? Package
        p[:package] = pkg_name
      end
    end
    # Reset target package name
    # not yet existing target package
    p[:target_package] = p[:package]
    # existing target
    p[:target_package] = "#{p[:package].name}" if p[:package].is_a? Package
    # user specified target name
    p[:target_package] = params[:target_package] if params[:target_package]
    # extend parameter given
    p[:target_package] += ".#{p[:link_target_project].name}" if @extend_names
  end

  def update_project_for_project(prj)
    updateprj = prj.update_instance(@up_attribute_namespace, @up_attribute_name)
    return updateprj if updateprj != prj
    nil
  end

  # add packages which link them in the same project to support build of source with multiple build descriptions
  def extend_packages_to_link(p)
    return unless p[:package].is_a? Package # only for local packages

    pkg = p[:package]
    if pkg.is_link?
      # is the package itself a local link ?
      link = Suse::Backend.get("/source/#{p[:package].project.name}/#{p[:package].name}/_link")
      ret = Xmlhash.parse(link.body)
      if !ret['project'] || ret['project'] == p[:package].project.name
        pkg = Package.get_by_project_and_name(p[:package].project.name, ret['package'])
      end
    end

    pkg.find_project_local_linking_packages.each do |llp|
      ap = llp
      # release projects have a second iteration, pointing to .$ID, use packages with original names instead
      innerp = llp.find_project_local_linking_packages
      if innerp.length == 1
        ap = innerp.first
      end

      target_package = ap.name
      target_package += '.' + p[:target_package].gsub(/^[^\.]*\./, '') if @extend_names
      release_name = ap.name if @extend_names

      # avoid double entries and therefore endless loops
      found = false
      @packages.each do |ep|
        found = true if ep[:package] == ap
      end
      unless found
        logger.debug "found local linked package in project #{p[:package].project.name}/#{ap.name}, " +
                     "adding it as well, pointing it to #{p[:package].name} for #{target_package}"
        @packages.push({ base_project: p[:base_project],
                         link_target_project: p[:link_target_project],
                         link_target_package: p[:package].name,
                         package: ap, target_package: target_package,
                         release_name: release_name, local_link: 1 })
      end
    end
  end

  def set_update_project_attribute
    aname = params[:update_project_attribute] || 'OBS:UpdateProject'
    update_project_at = aname.split(/:/)
    if update_project_at.length != 2
      raise ArgumentError.new "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
    end
    @up_attribute_namespace = update_project_at[0]
    @up_attribute_name = update_project_at[1]
  end

  def find_packages_to_branch
    @packages = []
    if params[:request]
      # find packages from request
      req = BsRequest.find_by_number(params[:request])

      req.bs_request_actions.each do |action|
        if action.source_package
          pkg = Package.get_by_project_and_name action.source_project, action.source_package
        end

        @packages.push({ link_target_project: action.source_project, package: pkg, target_package: "#{pkg.name}.#{pkg.project.name}" })
      end
    elsif params[:project] && params[:package]
      pkg = nil
      prj = Project.get_by_name params[:project]
      if params[:missingok]
        if Package.exists_by_project_and_name(params[:project], params[:package], follow_project_links: true, allow_remote_packages: true)
          raise NotMissingError.new "Branch call with missingok parameter but branched source (#{params[:project]}/#{params[:package]}) exists."
        end
      else
        pkg = Package.get_by_project_and_name params[:project], params[:package], {check_update_project: true}
        if prj.is_a?(Project) && prj.find_attribute('OBS', 'BranchTarget')
          @copy_from_devel = true
        else
          prj = pkg.project if pkg
        end
      end
      tpkg_name = params[:target_package]
      tpkg_name = params[:package] unless tpkg_name
      tpkg_name += ".#{prj.name}" if @extend_names
      if pkg
        # local package
        @packages.push({ base_project: prj, link_target_project: prj, package: pkg, rev: params[:rev], target_package: tpkg_name })
      else
        # remote or not existing package
        @packages.push({ base_project: prj,
                         link_target_project: (prj||params[:project]),
                         package: params[:package], rev: params[:rev], target_package: tpkg_name })
      end
    else
      @extend_names = true
      @copy_from_devel = true
      @add_repositories = true # osc mbranch shall create repos by default
      # find packages via attributes
      at = AttribType.find_by_name!(@attribute)
      if params[:value]
        Package.find_by_attribute_type_and_value(at, params[:value], params[:package]) do |p|
          logger.info "Found package instance #{p.project.name}/#{p.name} for attribute #{at.name} with value #{params[:value]}"
          @packages.push({ base_project: p.project, link_target_project: p.project, package: p, target_package: "#{p.name}.#{p.project.name}" })
        end
        # FIXME: how to handle linked projects here ? shall we do at all or has the tagger
        # (who creates the attribute) to create the package instance ?
      else
        # Find all direct instances of a package
        Package.find_by_attribute_type(at, params[:package]).each do |p|
          logger.info "Found package instance #{p.project.name}/#{p.name} for attribute #{at.name} and given package name #{params[:package]}"
          @packages.push({ base_project: p.project, link_target_project: p.project, package: p, target_package: "#{p.name}.#{p.project.name}" })
        end
        # Find all indirect instance via project links
        ltprj = nil
        Project.find_by_attribute_type(at).each do |lprj|
          # FIXME: this will not find packages on linked remote projects
          ltprj = lprj
          pkg2 = lprj.find_package(params[:package])
          unless pkg2.nil? || @packages.map { |p| p[:package] }.include?(pkg2) # avoid double instances
            logger.info "Found package instance via project link in #{pkg2.project.name}/#{pkg2.name}" +
                        "for attribute #{at.name} and given package name #{params[:package]}"
            if ltprj.find_attribute('OBS', 'BranchTarget').nil?
              ltprj = pkg2.project
            end
            @packages.push({ base_project: pkg2.project, link_target_project: ltprj,
                             package: pkg2, target_package: "#{pkg2.name}.#{pkg2.project.name}" })
          end
        end
      end
    end

    raise NotFoundError.new 'no packages found by search criteria' if @packages.empty?
  end

  def set_target_project
    if params[:target_project]
      @target_project = params[:target_project]
    else
      if params[:request]
        @target_project = User.current.branch_project_name("REQUEST_#{params[:request]}")
      elsif params[:project]
        @target_project = nil # to be set later after first source location lookup
      else
        @target_project = User.current.branch_project_name(@attribute.tr(':', '_'))
        @target_project += ":#{params[:package]}" if params[:package]
      end
      @auto_cleanup = ::Configuration.cleanup_after_days
    end
    if @target_project && !Project.valid_name?(@target_project)
      raise InvalidProjectNameError, "invalid project name '#{@target_project}'"
    end
  end
end
