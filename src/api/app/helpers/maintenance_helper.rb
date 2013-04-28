include ValidationHelper

module MaintenanceHelper

  # updates packages automatically generated in the backend after submitting a product file
  def create_new_maintenance_incident( maintenanceProject, baseProject = nil, request = nil, noaccess = false )
    mi = nil
    tprj = nil
    Project.transaction do
      mi = MaintenanceIncident.new( :maintenance_db_project => maintenanceProject ) 
      tprj = Project.new :name => mi.project_name
      if baseProject
        # copy as much as possible from base project
        tprj.title = baseProject.title.dup if baseProject.title
        tprj.description = baseProject.description.dup if baseProject.description
        tprj.save
        baseProject.flags.each do |f|
          tprj.flags.create(:status => f.status, :flag => f.flag)
        end
      else
        # mbranch call is enabling selected packages
        tprj.save
        tprj.flags.create( :position => 1, :flag => 'build', :status => "disable" )
      end
      # publish is disabled, just patchinfos get enabled
      tprj.flags.create( :flag => 'publish', :status => "disable" )
      if noaccess
        tprj.flags.create( :flag => 'access', :status => "disable" )
      end
      # take over roles from maintenance project
      maintenanceProject.project_user_role_relationships.each do |r| 
        ProjectUserRoleRelationship.create(
              :user => r.user,
              :role => r.role,
              :project => tprj
            )
      end
      maintenanceProject.project_group_role_relationships.each do |r| 
        ProjectGroupRoleRelationship.create(
              :group => r.group,
              :role => r.role,
              :project => tprj
            )
      end
      # set default bugowner if missing
      bugowner = Role.get_by_title("bugowner")
      unless tprj.project_user_role_relationships.where("role_id = ?", bugowner.id).first
        tprj.add_user( @http_user, bugowner )
      end
      # and write it
      tprj.set_project_type "maintenance_incident"
      tprj.store
      mi.db_project_id = tprj.id
      mi.save!
    end
    return mi
  end


  # generic branch function for package based, project wide or request based branch
  def do_branch params
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

    # set defaults
    unless params[:attribute]
      params[:attribute] = "OBS:Maintained"
    end
    target_project = nil
    if params[:target_project]
      target_project = params[:target_project]
    else
      if params[:request]
        target_project = "home:#{User.current.login}:branches:REQUEST_#{params[:request]}"
      elsif params[:project]
        target_project = nil # to be set later after first source location lookup
      else
        target_project = "home:#{User.current.login}:branches:#{params[:attribute].gsub(':', '_')}"
        target_project += ":#{params[:package]}" if params[:package]
      end
    end
    unless params[:update_project_attribute]
      params[:update_project_attribute] = "OBS:UpdateProject"
    end
    if target_project and not valid_project_name? target_project
      return { :status => 400, :errorcode => "invalid_project_name",
        :message => "invalid project name '#{target_project}'" }
    end
    add_repositories = params[:add_repositories]
    # use update project ?
    aname = params[:update_project_attribute]
    update_project_at = aname.split(/:/)
    if update_project_at.length != 2
      raise ArgumentError, "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
    end
    # create hidden project ?
    noaccess = false
    noaccess = true if params[:noaccess]
    # extend repo and package names ?
    extend_names = false
    extend_names = true if params[:extend_package_names]
    # copy from devel package instead branching ?
    copy_from_devel = false
    # explicit asked for maintenance branch ?
    if params[:maintenance]
      extend_names = true
      copy_from_devel = true
      add_repositories = true
    end

    # find packages to be branched
    @packages = []
    if params[:request]
      # find packages from request
      req = BsRequest.find(params[:request])

      req.bs_request_actions.each do |action|
        prj=nil
        pkg=nil
        if action.source_project || action.source_package
          if action.source_package
            pkg = Package.get_by_project_and_name action.source_project, action.source_package
          elsif action.source_project
            prj = Project.get_by_name action.source_project
          end
        end

        @packages.push({ :link_target_project => action.source_project, :package => pkg, :target_package => "#{pkg.name}.#{pkg.project.name}" })
      end
    elsif params[:project] and params[:package]
      pkg = nil
      prj = Project.get_by_name params[:project]
      if params[:missingok]
        if Package.exists_by_project_and_name(params[:project], params[:package], follow_project_links: true, allow_remote_packages: true)
          return { :status => 400, :errorcode => 'not_missing',
            :message => "Branch call with missingok paramater but branch source (#{params[:project]}/#{params[:package]}) exists." }
        end
      else
        pkg = Package.get_by_project_and_name params[:project], params[:package]
        unless prj.class == Project and prj.find_attribute("OBS", "BranchTarget")
          prj = pkg.project if pkg 
        end
      end
      tpkg_name = params[:target_package]
      tpkg_name = params[:package] unless tpkg_name
      tpkg_name += ".#{params[:project]}" if extend_names
      if pkg
        # local package
        @packages.push({ :base_project => prj, :link_target_project => prj, :package => pkg, :rev => params[:rev], :target_package => tpkg_name })
      else
        # remote or not existing package
        @packages.push({ :base_project => prj, :link_target_project => (prj||params[:project]), :package => params[:package], :rev => params[:rev], :target_package => tpkg_name })
      end
    else
      extend_names = true
      copy_from_devel = true
      add_repositories = true # osc mbranch shall create repos by default
      # find packages via attributes
      at = AttribType.find_by_name(params[:attribute])
      unless at
        return { :status => 403, :errorcode => 'not_found',
          :message => "The given attribute #{params[:attribute]} does not exist" }
      end
      if params[:value]
        Package.find_by_attribute_type_and_value( at, params[:value], params[:package] ) do |p|
          logger.info "Found package instance #{p.project.name}/#{p.name} for attribute #{at.name} with value #{params[:value]}"
          @packages.push({ :base_project => p.project, :link_target_project => p.project, :package => p, :target_package => "#{p.name}.#{p.project.name}" })
        end
        # FIXME: how to handle linked projects here ? shall we do at all or has the tagger (who creates the attribute) to create the package instance ?
      else
        # Find all direct instances of a package
        Package.find_by_attribute_type( at, params[:package] ).each do |p|
          logger.info "Found package instance #{p.project.name}/#{p.name} for attribute #{at.name} and given package name #{params[:package]}"
          @packages.push({ :base_project => p.project, :link_target_project => p.project, :package => p, :target_package => "#{p.name}.#{p.project.name}" })
        end
        # Find all indirect instance via project links
        ltprj = nil
        Project.find_by_attribute_type( at ).each do |lprj|
          # FIXME: this will not find packages on linked remote projects
          ltprj = lprj
          pkg2 = lprj.find_package( params[:package] )
          unless pkg2.nil? or @packages.map {|p| p[:package] }.include? pkg2 # avoid double instances
            logger.info "Found package instance via project link in #{pkg2.project.name}/#{pkg2.name} for attribute #{at.name} and given package name #{params[:package]}"
            if ltprj.find_attribute("OBS", "BranchTarget").nil?
              ltprj = pkg2.project
            end
            @packages.push({ :base_project => pkg2.project, :link_target_project => ltprj, :package => pkg2, :target_package => "#{pkg2.name}.#{pkg2.project.name}" })
          end
        end
      end
    end

    unless @packages.length > 0
      return { :status => 403, :errorcode => "not_found",
        :message => "no packages found by search criteria" }
    end

#    logger.debug "XXXXXXX BEFORE"
#    @packages.each do |p|
#      if p[:package].class == Package
#        logger.debug "X #{p[:package].project.name} #{p[:package].name} will point to #{p[:link_target_project].name}"
#      else
#        logger.debug "X #{p[:package]} will point to #{p[:link_target_project].inspect}"
#      end
#    end

    # lookup update project, devel project or local linked packages.
    # Just requests should be nearly the same
    unless params[:request]
      @packages.each do |p|
        next unless p[:link_target_project].class == Project # only for local source projects
        if p[:package].class == Package
          logger.debug "Check Package #{p[:package].project.name}/#{p[:package].name}"
        else
          logger.debug "Check package string #{p[:package]}"
        end
        pkg = p[:package]
        prj = p[:link_target_project]
        if pkg.class == Package
          prj = pkg.project
          pkg_name = pkg.name
        else
          pkg_name = pkg
        end

        # Check for defined update project
        if prj and a = prj.find_attribute(update_project_at[0], update_project_at[1]) and a.values[0]
          if pa = Package.find_by_project_and_name( a.values[0].value, pkg_name )
            # We have a package in the update project already, take that
            p[:package] = pa
            unless p[:link_target_project].class == Project and p[:link_target_project].find_attribute("OBS", "BranchTarget")
              p[:link_target_project] = pa.project
              logger.info "branch call found package in update project #{pa.project.name}"
            end
          else
            update_prj = Project.find_by_name( a.values[0].value )
            if update_prj
              unless p[:link_target_project].class == Project and p[:link_target_project].find_attribute("OBS", "BranchTarget")
                p[:link_target_project] = update_prj
              end
              update_pkg = update_prj.find_package( pkg_name )
              if update_pkg
                # We have no package in the update project yet, but sources are reachable via project link
                if update_prj.develproject and up = update_prj.develproject.find_package(pkg.name)
                  # nevertheless, check if update project has a devel project which contains an instance
                  p[:package] = up
                  unless p[:link_target_project].class == Project and p[:link_target_project].find_attribute("OBS", "BranchTarget")
                    p[:link_target_project] = up.project unless copy_from_devel
                  end
                  logger.info "link target will create package in update project #{up.project.name} for #{prj.name}"
                else
                  p[:package] = pkg
                  logger.info "link target will use old update in update project #{pkg.project.name} for #{prj.name}"
                end
              else
                # The defined update project can't reach the package instance at all.
                # So we need to create a new package and copy sources
                params[:missingok] = 1 # implicit missingok or better report an error ?
                p[:copy_from_devel] = p[:package] if p[:package].class == Package
                p[:package] = pkg_name
              end
            end
          end
          # Reset target package name
          # not yet existing target package
          p[:target_package] = p[:package]
          # existing target
          p[:target_package] = "#{p[:package].name}" if p[:package].class == Package
          # user specified target name
          p[:target_package] = params[:target_package] if params[:target_package]
          # extend parameter given
          p[:target_package] += ".#{p[:link_target_project].name}" if extend_names
        end
   
        # validate and resolve devel package or devel project definitions
        unless params[:ignoredevel] or p[:copy_from_devel]

          if copy_from_devel and p[:package].class == Package
            p[:copy_from_devel] = p[:package].resolve_devel_package
            logger.info "sources will get copied from devel package #{p[:copy_from_devel].project.name}/#{p[:copy_from_devel].name}" unless p[:copy_from_devel] == p[:package]
          end

          if (p[:copy_from_devel].nil? or p[:copy_from_devel] == p[:package]) \
             and p[:package].class == Package \
             and p[:link_target_project].class == Project and p[:link_target_project].project_type == "maintenance_release" \
             and mp = p[:link_target_project].maintenance_project
            # no defined devel area or no package inside, but we branch from a release are: check in open incidents

            path = "/search/package/id?match=(linkinfo/@package=\"#{CGI.escape(p[:package].name)}\"+and+linkinfo/@project=\"#{CGI.escape(p[:link_target_project].name)}\""
            path += "+and+starts-with(@project,\"#{CGI.escape(mp.name)}%3A\"))"
            answer = Suse::Backend.post path, nil
            data = REXML::Document.new(answer.body)
            incident_pkg = nil
            data.elements.each("collection/package") do |e|
              ipkg = Package.find_by_project_and_name( e.attributes["project"], e.attributes["name"] )
              if ipkg.nil?
                logger.error "read permission or data inconsistency, backend delivered package as linked package where no database object exists: #{e.attributes["project"]} / #{e.attributes["name"]}"
              else
                # is incident ?
                if ipkg.project.project_type == "maintenance_incident" 
                  # is a newer incident ?
                  if incident_pkg.nil? or ipkg.project.name.gsub(/.*:/,'').to_i > incident_pkg.project.name.gsub(/.*:/,'').to_i
                    incident_pkg = ipkg
                  end
                end
              end
            end  
            if incident_pkg
              p[:copy_from_devel] = incident_pkg
              logger.info "sources will get copied from incident package #{p[:copy_from_devel].project.name}/#{p[:copy_from_devel].name}"
            end
          elsif not copy_from_devel and p[:package].class == Package and ( p[:package].develpackage or p[:package].project.develproject )
            p[:package] = p[:package].resolve_devel_package
            p[:link_target_project] = p[:package].project
            p[:target_package] = p[:package].name
            p[:target_package] += ".#{p[:link_target_project].name}" if extend_names
            # user specified target name
            p[:target_package] = params[:target_package] if params[:target_package]
            logger.info "devel project is #{p[:link_target_project].name} #{p[:package].name}"
          end
        end

        # set default based on first found package location
        unless target_project
          target_project = "home:#{User.current.login}:branches:#{p[:link_target_project].name}"
        end

        # link against srcmd5 instead of plain revision
        unless p[:rev].nil?
          begin
            dir = Directory.find({ :project => params[:project], :package => params[:package], :rev => params[:rev]})
          rescue
            return { :status => 400, :errorcode => 'invalid_filelist',
              :message => "no such revision" }
          end
          if dir.has_attribute? 'srcmd5'
            p[:rev] = dir.srcmd5
          else
            return { :status => 400, :errorcode => 'invalid_filelist',
              :message => "no srcmd5 revision found" }
          end
        end
      end

      # add packages which link them in the same project to support build of source with multiple build descriptions
      @packages.each do |p|
        next unless p[:package].class == Package # only for local packages

        pkg = p[:package]
        if pkg.package_kinds.find_by_kind 'link'
          # is the package itself a local link ?
          link = Suse::Backend.get( "/source/#{p[:package].project.name}/#{p[:package].name}/_link")
          ret = ActiveXML::Node.new(link.body)
          if ret.project.nil? or ret.project == p[:package].project.name
            pkg = Package.get_by_project_and_name(p[:package].project.name, ret.package)
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
          target_package += "." + p[:target_package].gsub(/^[^\.]*\./,'') if extend_names

          # avoid double entries and therefore endless loops
          found = false
          @packages.each do |ep|
            found = true if ep[:package] == ap
          end
          unless found
            logger.info "found local linked package in project #{p[:package].project.name}/#{ap.name}, adding it as well, pointing it to #{p[:package].name} for #{target_package}"
            @packages.push({ :base_project => p[:base_project], :link_target_project => p[:link_target_project], :link_target_package => p[:package].name, :package => ap, :target_package => target_package, :local_link => 1 })
          end
        end
      end
    end

#    logger.debug "XXXXXXX AFTER"
#    @packages.each do |p|
#      if p[:package].class == Package
#        logger.debug "X #{p[:package].project.name} #{p[:package].name} will point to #{p[:link_target_project].name}"
#      else
#        logger.debug "X #{p[:package]} will point to #{p[:link_target_project].inspect}"
#      end
#    end

    unless target_project
      target_project = "home:#{User.current.login}:branches:#{params[:project]}"
    end

    #
    # Data collection complete at this stage
    #

    # Just report the result in dryrun, but not action
    if params[:dryrun]
      # dry run, just report the result, but no effect
      @packages.sort! { |x,y| x[:target_package] <=> y[:target_package] }
      builder = Builder::XmlMarkup.new( :indent => 2 )
      xml = builder.collection() do
        @packages.each do |p|
          if p[:package].class == Package
            builder.package(:project => p[:link_target_project].name, :package => p[:package].name) do
              builder.target(:project => target_project, :package => p[:target_package])
            end
          else
            builder.package(:project => p[:link_target_project], :package => p[:package]) do 
              builder.target(:project => target_project, :package => p[:target_package])
            end
          end
        end
      end
      return { :status => 200, :text => xml, :content_type => "text/xml" }
    end

    #create branch project
    if Project.exists_by_name target_project
      if noaccess
        return { :status => 403, :errorcode => "create_project_no_permission",
          :message => "The destination project already exists, so the api can't make it not readable" }
      end
    else
      # permission check
      unless User.current.can_create_project?(target_project)
        return { :status => 403, :errorcode => "create_project_no_permission",
          :message => "no permission to create project '#{target_project}' while executing branch command" }
      end

      title = "Branch project for package #{params[:package]}"
      description = "This project was created for package #{params[:package]} via attribute #{params[:attribute]}"
      if params[:request]
        title = "Branch project based on request #{params[:request]}"
        description = "This project was created as a clone of request #{params[:request]}"
      end
      add_repositories = true # new projects shall get repositories
      Project.transaction do
        tprj = Project.new :name => target_project, :title => title, :description => description
        tprj.add_user User.current, "maintainer"
        tprj.flags.create( :flag => 'build', :status => "disable" ) if extend_names
        tprj.flags.create( :flag => 'access', :status => "disable" ) if noaccess
        tprj.store
      end
      if params[:request]
        ans = AttribNamespace.find_by_name "OBS"
        at = ans.attrib_types.where(:name => "RequestCloned").first

        tprj = Project.get_by_name target_project
        a = Attrib.new(:project => tprj, :attrib_type => at)
        a.values << AttribValue.new(:value => params[:request], :position => 1)
        a.save
      end
    end

    tprj = Project.get_by_name target_project
    unless User.current.can_modify_project?(tprj)
      return { :status => 403, :errorcode => "modify_project_no_permission",
        :message => "no permission to modify project '#{target_project}' while executing branch project command" }
    end

    # create package branches
    # collect also the needed repositories here
    response = nil
    @packages.each do |p|
      pac = p[:package]
      if pac.class == Package
        prj = pac.project
      elsif p[:link_target_project].class == Project
        # new package for local project
        prj = p[:link_target_project]
      else
        # package in remote project
        prj = p[:project]
      end

      # find origin package to be branched
      branch_target_package = p[:target_package]
      #proj_name = target_project.gsub(':', '_')
      pack_name = branch_target_package.gsub(':', '_')

      # create branch package
      # no find_package call here to check really this project only
      if tpkg = tprj.packages.find_by_name(pack_name)
        unless params[:force]
          return { :status => 400, :errorcode => "double_branch_package",
            :message => "branch target package already exists: #{tprj.name}/#{tpkg.name}" }
        end
      else
        if pac.class == Package
          tpkg = tprj.packages.new(:name => pack_name, :title => pac.title, :description => pac.description)
        else
          tpkg = tprj.packages.new(:name => pack_name)
        end
        tprj.packages << tpkg
      end

      # create repositories, if missing
      if p[:link_target_project].class == Project
        p[:link_target_project].repositories.each do |repo|
          repoName = repo.name
          if extend_names
            repoName = p[:link_target_project].name.gsub(':', '_')
            if p[:link_target_project].repositories.count > 1
              # keep short names if project has just one repo
              repoName += "_"+repo.name
            end
          end
          if add_repositories
            unless tprj.repositories.find_by_name(repoName)
              trepo = tprj.repositories.create :name => repoName
              repo.repository_architectures.each do |ra|
                trepo.repository_architectures.create :architecture => ra.architecture, :position => ra.position
              end
              trepo.path_elements.create(:link => repo, :position => 1)
              trigger = nil # manual
              trigger = "maintenance" if MaintenanceIncident.find_by_db_project_id( tprj.id ) # is target an incident project ?
              trepo.release_targets.create(:target_repository => repo, :trigger => trigger) if p[:link_target_project].project_type == "maintenance_release"
            end
            # enable package builds if project default is disabled
            tpkg.flags.create( :position => 1, :flag => 'build', :status => "enable", :repo => repoName ) if tprj.flags.find_by_flag_and_status( 'build', 'disable' )
            # take over debuginfo config from origin project
            tpkg.flags.create( :position => 1, :flag => 'debuginfo', :status => "enable", :repo => repoName ) if prj.enabled_for?('debuginfo', repo.name, nil)
          end
        end
        if add_repositories
          # take over flags, but explicit disable publishing by default and enable building. Ommiting also lock or we can not create packages
          p[:link_target_project].flags.each do |f|
            unless [ "build", "publish", "lock" ].include?(f.flag)
              tprj.flags.create(status: f.status, flag: f.flag, architecture: f.architecture, repo: f.repo)
            end
          end
          tprj.flags.create(:status => "disable", :flag => 'publish') unless tprj.flags.find_by_flag_and_status( 'publish', 'disable' )
        end
      else
        # FIXME for remote project instances
      end
      tpkg.store

      if p[:local_link]
        # copy project local linked packages
        Suse::Backend.post "/source/#{tpkg.project.name}/#{tpkg.name}?cmd=copy&oproject=#{CGI.escape(p[:link_target_project].name)}&opackage=#{CGI.escape(p[:package].name)}&user=#{CGI.escape(User.current.login)}", nil
        # and fix the link
        link = Suse::Backend.get "/source/#{tpkg.project.name}/#{tpkg.name}/_link"
        ret = ActiveXML::Node.new(link.body)
        ret.delete_attribute('project') # its a local link, project name not needed
        linked_package = p[:link_target_package]
        linked_package = params[:target_package] if params[:target_package] and params[:package] == ret.package  # user enforce a rename of base package
        linked_package += "." + p[:link_target_project].name.gsub(':', '_') if extend_names
        ret.set_attribute('package', linked_package)
        answer = Suse::Backend.put "/source/#{tpkg.project.name}/#{tpkg.name}/_link?user=#{CGI.escape(User.current.login)}", ret.dump_xml
        tpkg.sources_changed
      else
        path = "/source/#{URI.escape(tpkg.project.name)}/#{URI.escape(tpkg.name)}"
        oproject = p[:link_target_project].class == Project ? p[:link_target_project].name : p[:link_target_project]
        myparam = { :cmd => "branch",
                    :noservice => "1",
                    :oproject => oproject,
                    :opackage => p[:package],
                    :user => User.current.login,
                  }
        myparam[:opackage] = p[:package].name if p[:package].class == Package
        myparam[:orev] = p[:rev] if p[:rev] and not p[:rev].empty?
        myparam[:missingok] = "1" if params[:missingok]
        path <<  Suse::Backend.build_query_from_hash(myparam, [:cmd, :oproject, :opackage, :user, :comment, :orev, :missingok])
        # branch sources in backend
        answer = Suse::Backend.post path, nil
        if response
          # multiple package transfers, just tell the target project
          response = {:targetproject => tpkg.project.name}
        else
          # just a single package transfer, detailed answer
          response = {:targetproject => tpkg.project.name, :targetpackage => tpkg.name, :sourceproject => oproject, :sourcepackage => myparam[:opackage]}
        end

        # fetch newer sources from devel package, if defined
        if p[:copy_from_devel] and p[:copy_from_devel].project != tpkg.project
          msg="fetch+updates+from+devel+package+#{CGI.escape(p[:copy_from_devel].project.name)}/#{CGI.escape(p[:copy_from_devel].name)}"
          msg="fetch+updates+from+open+incident+project+#{CGI.escape(p[:copy_from_devel].project.name)}" if p[:copy_from_devel].project.project_type == "maintenance_incident"
          answer = Suse::Backend.post "/source/#{tpkg.project.name}/#{tpkg.name}?cmd=copy&keeplink=1&expand=1&oproject=#{CGI.escape(p[:copy_from_devel].project.name)}&opackage=#{CGI.escape(p[:copy_from_devel].name)}&user=#{CGI.escape(User.current.login)}&comment=#{msg}", nil
        end

        tpkg.sources_changed
      end
    end

    # store project data in DB and XML
    tprj.store

    # all that worked ? :)
    return { :status => 200, :data => response }
  end

end
