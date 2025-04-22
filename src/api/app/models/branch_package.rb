class BranchPackage
  attr_accessor :params

  include BranchPackage::Errors

  # generic branch function for package based, project wide or request based branch
  def initialize(params)
    self.params = params

    # set defaults
    @attribute = params[:attribute] || 'OBS:Maintained'
    @target_project = nil
    @auto_cleanup = nil
    @add_repositories = params[:add_repositories]
    # set on fork command only, skips all souce operations here
    @scmsync = params[:scmsync]
    # check if repository path elements do use each other and adapt our own path elements
    @update_path_elements = params[:update_path_elements]
    # create hidden project ?
    @noaccess = params[:noaccess]
    # extend repo and package names ?
    @extend_names = params[:extend_package_names]
    @rebuild_policy = params[:add_repositories_rebuild]
    @block_policy = params[:add_repositories_block]
    raise InvalidArgument unless [nil, 'all', 'local', 'never'].include?(@block_policy)
    raise InvalidArgument unless [nil, 'transitive', 'direct', 'local', 'copy'].include?(@rebuild_policy)

    # copy from devel package instead branching ?
    @copy_from_devel = false
    @copy_from_devel = true if params[:newinstance]
    # explicit asked for maintenance branch ?
    return unless params[:maintenance]

    @extend_names = true
    @copy_from_devel = true
    @add_repositories = true
    @update_path_elements = true
  end

  delegate :logger, to: :Rails

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

    if @scmsync.blank?
      find_packages_to_branch

      # lookup update project, devel project or local linked packages.
      # Just requests should be nearly the same
      find_package_targets unless params[:request]

      # it is okay to branch the same package multiple times when having
      # different link_target_projects
      @packages.uniq! { |x| x[:target_package] }
    end

    @target_project ||= User.session!.branch_project_name(params[:project])

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

    raise Project::WritePermissionError, "no permission to modify project '#{@target_project}' while executing branch project command" unless User.session!.can_modify?(tprj)

    # special fork handling
    return { data: create_fork(tprj) } if @scmsync.present?

    # all that worked ? :)
    { data: create_branch_packages(tprj) }
  end

  private

  def branch_target_package(package_hash)
    return unless package_hash.key?(:target_package)

    package_hash[:target_package].tr(':', '_')
  end

  def copy_package_message(package_hash)
    copy_from_devel = package_hash[:copy_from_devel]

    if copy_from_devel.project.maintenance_incident?
      "fetch updates from open incident project #{copy_from_devel.project.name}"
    else
      "fetch updates from devel package #{copy_from_devel.project.name}/#{copy_from_devel.name}"
    end
  end

  def add_request_cloned_attribute(project)
    type = AttribType.find_by_namespace_and_name!('OBS', 'RequestCloned')
    value = AttribValue.new(value: params[:request], position: 1)
    Attrib.create(project: project, attrib_type: type, values: [value])
  end

  def add_autocleanup_attribute(tprj)
    at = AttribType.find_by_namespace_and_name!('OBS', 'AutoCleanup')
    a = Attrib.new(project: tprj, attrib_type: at)
    a.values << AttribValue.new(value: (Time.now + @auto_cleanup.days), position: 1)
    a.save
  end

  def check_for_update_project(package_hash)
    check_for_update = BranchPackage::CheckForUpdate.new(package_hash: package_hash,
                                                         update_attribute_namespace: @up_attribute_namespace,
                                                         update_attribute_name: @up_attribute_name,
                                                         extend_names: @extend_names, copy_from_devel: @copy_from_devel,
                                                         params: params)
    check_for_update.check_for_update_project
    params[:missingok] = 1 if check_for_update.missing_ok?
    check_for_update.package_hash
  end

  # create package container, we could take a bit more from base one, but these
  # would be just the cosmetic parts like title and description. Other elemnts should
  # not be used anyway for scmsync packages.
  def create_fork(project)
    package = nil
    unless params[:package] == '_project'
      package = project.packages.find_or_initialize_by(name: params[:package])
      package.scmsync = @scmsync
      package.store
    end

    # add repositories
    opts = {}
    opts[:rebuild] = @rebuild_policy if @rebuild_policy
    opts[:block]   = @block_policy   if @block_policy
    source_project = Project.get_by_name(params[:project])
    project.branch_to_repositories_from(source_project, package, opts)
    project.sync_repository_pathes
    project.scmsync = @scmsync if params[:package] == '_project'
    project.store
    if params[:package] == '_project'
      return { targetproject: project.name,
               sourceproject: params[:project] }
    end

    { targetproject: project.name,
      targetpackage: package.name,
      sourceproject: params[:project],
      sourcepackage: params[:package] }
  end

  def create_branch_packages(tprj)
    # collect also the needed repositories here
    response = nil
    @packages.each do |p|
      raise CanNotBranchPackage, "project is developed at #{p[:link_target_project].scmsync}. Fork it instead." if p[:link_target_project].try(:scmsync).present?
      raise CanNotBranchPackage, "package is developed at #{p[:package].scmsync}. Fork it instead" if p[:package].try(:scmsync).present?

      pac = p[:package]
      if pac.instance_of?(Package)
        a = pac.find_attribute('OBS', 'RejectBranch')
        raise BranchRejected, "Branching is not allowed because: #{a.values.first.value}" if a && a.values.first
      end

      # find origin package to be branched
      pack_name = branch_target_package(p)

      # create branch package
      # no find_package call here to check really this project only
      tpkg = tprj.packages.find_by_name(pack_name)

      if tpkg
        raise DoubleBranchPackageError.new(tprj.name, tpkg.name), "branch target package already exists: #{tprj.name}/#{tpkg.name}" unless params[:force]
      else
        if pac.is_a?(Package)
          tpkg = tprj.packages.new(name: pack_name, title: pac.title, description: pac.description, url: pac.url)
          tpkg.bcntsynctag = pac.bcntsynctag
        else
          tpkg = tprj.packages.new(name: pack_name)
        end
        tpkg.bcntsynctag << ".#{p[:link_target_project].name.tr(':', '_')}" if tpkg.bcntsynctag && @extend_names
        tpkg.releasename = p[:release_name]
      end
      tpkg.store

      if p[:local_link]
        # copy project local linked packages
        Backend::Api::Sources::Package.copy(tpkg.project.name, tpkg.name, p[:link_target_project].name, p[:package].name, User.session!.login)
        # and fix the link
        ret = Nokogiri::XML(tpkg.source_file('_link'), &:strict).root
        ret.remove_attribute('project') # its a local link, project name not needed
        linked_package = p[:link_target_package]
        # user enforce a rename of base package
        linked_package = params[:target_package] if params[:target_package] && params[:package] == ret['package']
        linked_package += ".#{p[:link_target_project].name.tr(':', '_')}" if @extend_names
        ret['package'] = linked_package
        Backend::Api::Sources::Package.write_link(tpkg.project.name, tpkg.name, User.session!.login, ret.to_xml)
      else
        opackage = p[:package]
        oproject = p[:link_target_project]
        oproject = p[:link_target_project].name if p[:link_target_project].is_a?(Project)
        opackage = p[:package].name if p[:package].is_a?(Package)

        # branch sources in backend
        opts = {}
        opts[:missingok] = '1' if params[:missingok].present?
        opts[:noservice] = '1' if params[:noservice].present?
        opts[:orev] = p[:rev] if p[:rev].present?
        # New incident updates need the vrev extension
        if tpkg.project.maintenance_incident? && p[:package].is_a?(Package) &&
           p[:package].project != p[:link_target_project]
          opts[:extendvrev] = '1'
        end
        tpkg.branch_from(oproject, opackage, opts)

        response = if response
                     # multiple package transfers, just tell the target project
                     { targetproject: tpkg.project.name }
                   else
                     # just a single package transfer, detailed answer
                     { targetproject: tpkg.project.name, targetpackage: tpkg.name, sourceproject: oproject, sourcepackage: opackage }
                   end

        # fetch newer sources from devel package, if defined
        if p[:copy_from_devel] && p[:copy_from_devel].project != tpkg.project && !p[:rev]
          msg = copy_package_message(p)
          Backend::Api::Sources::Package.copy(tpkg.project.name, tpkg.name, p[:copy_from_devel].project.name, p[:copy_from_devel].name,
                                              User.session!.login, comment: msg, keeplink: 1, expand: 1)
        end
      end
      tpkg.sources_changed

      # create repositories, if missing
      if @add_repositories
        opts = {}
        opts[:extend_names] = true if @extend_names
        opts[:rebuild] = @rebuild_policy if @rebuild_policy
        opts[:block]   = @block_policy   if @block_policy
        tprj.branch_to_repositories_from(p[:link_target_project], tpkg, opts)
      end

      tpkg.add_channels if tprj.maintenance_incident? && !tprj.parent.find_attribute('OBS', 'SkipChannelBranch')
    end
    tprj.sync_repository_pathes if @update_path_elements

    # store project data in DB and XML
    tprj.store
    response
  end

  def create_branch_project
    if Project.exists_by_name(@target_project)
      raise CreateProjectNoPermission, "The destination project already exists, so the api can't make it not readable" if @noaccess

      tprj = Project.get_by_name(@target_project)
    else
      # permission check
      raise CreateProjectNoPermission, "no permission to create project '#{@target_project}' while executing branch command" unless User.session!.can_create_project?(@target_project)

      title = "Branch project for package #{params[:package]}"
      description = "This project was created for package #{params[:package]} via attribute #{@attribute}"
      url = params[:target_project_url] || Project.find_by_name(params[:project]).try(:url)
      if params[:request]
        title = "Branch project based on request #{params[:request]}"
        description = "This project was created as a clone of request #{params[:request]}"
      end
      @add_repositories = true # new projects shall get repositories
      tprj = Project.new(name: @target_project, title: title, description: description, url: url)
      tprj.relationships.new(user: User.session!, role: Role.find_by_title!('maintainer'))
      tprj.flags.new(flag: 'build', status: 'disable') if @extend_names
      tprj.flags.new(flag: 'access', status: 'disable') if @noaccess
      tprj.store
      add_autocleanup_attribute(tprj) if @auto_cleanup
      add_request_cloned_attribute(tprj) if params[:request]
    end
    tprj
  end

  def determine_details_about_package_to_branch(p)
    return unless p[:link_target_project].is_a?(Project) # only for local source projects

    check_for_update_project(p) unless params[:ignoredevel]

    if params[:newinstance]
      p[:link_target_project] = Project.get_by_name(params[:project])
      p[:target_package] = if p[:package].is_a?(Package)
                             p[:package].name
                           else
                             p[:package]
                           end
      p[:target_package] += ".#{p[:link_target_project].name}" if @extend_names
    end
    if @extend_names
      p[:release_name] = p[:package].is_a?(String) ? p[:package] : p[:package].name
    end
    if @extend_names
      p[:release_name] = if p[:package].is_a?(String)
                           p[:package]
                         else
                           p[:package].releasename || p[:package].name
                         end
    end

    # validate and resolve devel package or devel project definitions
    unless params[:ignoredevel] || p[:copy_from_devel]

      devel_package = p[:package].find_devel_package if p[:package].is_a?(Package)
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
      @target_project = User.session!.branch_project_name(p[:link_target_project])
      @auto_cleanup = ::Configuration.cleanup_after_days
      @auto_cleanup ||= 14 if p[:base_project].try(:image_template?)
    end

    # link against srcmd5 instead of plain revision
    expand_rev_to_srcmd5(p) if p[:rev]
  end

  def expand_rev_to_srcmd5(p)
    begin
      dir = Xmlhash.parse(Backend::Api::Sources::Package.files(params[:project], params[:package], rev: params[:rev]))
    rescue Backend::NotFoundError
      raise InvalidFilelistError, 'no such revision'
    end
    p[:rev] = dir['srcmd5']
    return if p[:rev]

    raise InvalidFilelistError, 'no srcmd5 revision found'
  end

  # add packages which link them in the same project to support build of source with multiple build descriptions
  def extend_packages_to_link(p)
    return unless p[:package].is_a?(Package) # only for local packages

    pkg = p[:package]
    if pkg.link?
      # is the package itself a local link ?
      link = Backend::Api::Sources::Package.link_info(p[:package].project.name, p[:package].name)
      ret = Xmlhash.parse(link)
      pkg = Package.get_by_project_and_name(p[:package].project.name, ret['package']) if !ret['project'] || ret['project'] == p[:package].project.name
    end

    pkg.find_project_local_linking_packages.each do |llp|
      ap = llp
      # release projects have a second iteration, pointing to .$ID, use packages with original names instead
      innerp = llp.find_project_local_linking_packages
      ap = innerp.first if innerp.length == 1

      target_package = ap.name
      target_package += ".#{p[:target_package].gsub(/^[^.]*\./, '')}" if @extend_names
      release_name = ap.name if @extend_names

      # avoid double entries and therefore endless loops
      found = false
      @packages.each do |ep|
        found = true if ep[:package] == ap
      end
      next if found

      logger.debug "found local linked package in project #{p[:package].project.name}/#{ap.name}, " \
                   "adding it as well, pointing it to #{p[:package].name} for #{target_package}"
      @packages.push(base_project: p[:base_project],
                     link_target_project: p[:link_target_project],
                     link_target_package: p[:package].name,
                     package: ap, target_package: target_package,
                     release_name: release_name, local_link: 1)
    end
  end

  def find_package_targets
    @packages.each do |p|
      determine_details_about_package_to_branch(p)
    end

    @packages.each { |p| extend_packages_to_link(p) }

    # avoid double hits eg, when the same update project is used by multiple GA projects
    seen = {}
    @packages.each do |p|
      @packages.delete(p) if seen[p[:package]]
      seen[p[:package]] = true
    end
  end

  def find_packages_to_branch
    @packages = []
    if params[:request]
      # find packages from request
      req = BsRequest.find_by_number(params[:request])

      req.bs_request_actions.each do |action|
        pkg = Package.get_by_project_and_name(action.source_project, action.source_package) if action.source_package

        @packages.push(link_target_project: action.source_project, package: pkg, target_package: "#{pkg.name}.#{pkg.project.name}")
      end
    elsif params[:project] && params[:package]
      pkg = nil
      prj = Project.get_by_name(params[:project])
      tpkg_name = params[:target_package]
      if params[:missingok]
        raise NotMissingError, "Branch call with missingok parameter but branched source (#{params[:project]}/#{params[:package]}) exists." if Package.exists_by_project_and_name(params[:project], params[:package],
                                                                                                                                                                                  allow_remote_packages: true)
      else
        pkg = Package.get_by_project_and_name(params[:project], params[:package], check_update_project: params[:ignoredevel].blank?)
        if prj.is_a?(Project) && prj.find_attribute('OBS', 'BranchTarget')
          @copy_from_devel = true
        elsif pkg
          prj = pkg.project
          tpkg_name ||= pkg.releasename
        end
      end
      tpkg_name ||= params[:package]
      if @extend_names
        tprj_name = prj.try(:name) || params[:project]
        tpkg_name += ".#{tprj_name}"
      end
      if pkg
        # local package
        @packages.push(base_project: prj, link_target_project: prj, package: pkg, rev: params[:rev], target_package: tpkg_name)
      else
        # remote or not existing package
        @packages.push(base_project: prj,
                       link_target_project: prj || params[:project],
                       package: params[:package], rev: params[:rev], target_package: tpkg_name)
      end
    else
      @extend_names = true
      @copy_from_devel = true
      @add_repositories = true # osc mbranch shall create repos by default
      # find packages via attributes
      at = AttribType.find_by_name!(@attribute)
      if params[:value]
        PackagesFinder.new.find_by_attribute_type_and_value(at, params[:value], params[:package]) do |p|
          logger.info "Found package instance #{p.project.name}/#{p.name} for attribute #{at.name} with value #{params[:value]}"
          @packages.push(base_project: p.project, link_target_project: p.project, package: p, target_package: "#{p.name}.#{p.project.name}")
        end
        # FIXME: how to handle linked projects here ? shall we do at all or has the tagger
        # (who creates the attribute) to create the package instance ?
      else
        # Find all direct instances of a package
        PackagesFinder.new.find_by_attribute_type(at, params[:package]).each do |p|
          logger.info "Found package instance #{p.project.name}/#{p.name} for attribute #{at.name} and given package name #{params[:package]}"
          @packages.push(base_project: p.project, link_target_project: p.project, package: p, target_package: "#{p.name}.#{p.project.name}")
        end
        # Find all indirect instance via project links
        ltprj = nil
        Project.joins(:attribs).where(attribs: { attrib_type_id: at.id }).find_each do |lprj|
          # FIXME: this will not find packages on linked remote projects
          ltprj = lprj
          pkg2 = lprj.find_package(params[:package])
          next if pkg2.nil? || @packages.pluck(:package).include?(pkg2) # avoid double instances

          logger.info "Found package instance via project link in #{pkg2.project.name}/#{pkg2.name}" \
                      "for attribute #{at.name} and given package name #{params[:package]}"
          ltprj = pkg2.project if ltprj.find_attribute('OBS', 'BranchTarget').nil?
          @packages.push(base_project: pkg2.project, link_target_project: ltprj,
                         package: pkg2, target_package: "#{pkg2.name}.#{pkg2.project.name}")
        end
      end
    end

    raise NotFoundError, 'no packages found by search criteria' if @packages.empty?
  end

  def lookup_incident_pkg(p)
    return unless p[:package].is_a?(Package)
    return if p[:link_target_project].maintenance_projects.empty?

    BranchPackage::LookupIncidentPackage.new(p).package
  end

  def report_dryrun
    BranchPackage::DryRun::Report.new(@packages, @target_project).to_xml
  end

  def set_target_project
    target_project_set = BranchPackage::SetTargetProject.new(params)
    raise InvalidProjectNameError, 'invalid project name' unless target_project_set.valid?

    @target_project = target_project_set.target_project
    @auto_cleanup = target_project_set.auto_cleanup
  end

  def set_update_project_attribute
    aname = params[:update_project_attribute] || 'OBS:UpdateProject'
    update_project_at = aname.split(':')
    raise ArgumentError, "attribute '#{aname}' must be in the $NAMESPACE:$NAME style" if update_project_at.length != 2

    @up_attribute_namespace = update_project_at[0]
    @up_attribute_name = update_project_at[1]
  end
end
