include ValidationHelper

module MaintenanceHelper

  # updates packages automatically generated in the backend after submitting a product file
  def create_new_maintenance_incident( maintenanceProject, baseProject = nil, request = nil, noaccess = false )
    mi = nil
    tprj = nil
    Project.transaction do
      mi = MaintenanceIncident.new( :maintenance_db_project => maintenanceProject ) 
      tprj = Project.create :name => mi.project_name
      if baseProject
        # copy as much as possible from base project
        tprj.title = baseProject.title.dup if baseProject.title
        tprj.description = baseProject.description.dup if baseProject.description
        baseProject.flags.each do |f|
          tprj.flags.create(:status => f.status, :flag => f.flag)
        end
      else
        # mbranch call is enabling selected packages
        tprj.flags.create( :position => 1, :flag => 'build', :status => 'disable')
      end
      # publish is disabled, just patchinfos get enabled
      tprj.flags.create( :flag => 'publish', :status => 'disable')
      if noaccess
        tprj.flags.create( :flag => 'access', :status => 'disable')
      end
      # take over roles from maintenance project
      maintenanceProject.relationships.each do |r| 
        tprj.relationships.create(user: r.user, role: r.role, group: r.group)
      end
      # set default bugowner if missing
      bugowner = Role.rolecache['bugowner']
      unless tprj.relationships.users.where('role_id = ?', bugowner.id).exists?
        tprj.add_user( @http_user, bugowner )
      end
      # and write it
      tprj.set_project_type 'maintenance_incident'
      tprj.store
      mi.db_project_id = tprj.id
      mi.save!
    end
    return mi
  end

  def release_package(sourcePackage, targetProjectName, targetPackageName,
                      filterSourceRepository = nil, request = nil, setrelease = nil)
    targetProject = Project.get_by_name targetProjectName

    # create package container, if missing
    tpkg = create_package_container_if_missing(sourcePackage, targetPackageName, targetProject)

    # detect local links
    begin
      link = sourcePackage.source_file('_link')
      link = ActiveXML::Node.new(link)
    rescue ActiveXML::Transport::Error
      link = nil
    end
    if link and (link.value(:project).nil? or link.value(:project) == sourcePackage.project.name)
      release_package_relink(link, request, targetPackageName, targetProject, tpkg)
    else
      # copy sources
      release_package_copy_sources(request, sourcePackage, targetPackageName, targetProject)
      tpkg.sources_changed
    end

    # copy binaries
    copy_binaries(filterSourceRepository, sourcePackage, targetPackageName, targetProject, setrelease)

    # create or update main package linking to incident package
    unless sourcePackage.is_patchinfo?
      release_package_create_main_package(request, sourcePackage, targetPackageName, targetProject)
    end

    # publish incident if source is read protect, but release target is not. assuming it got public now.
    if f=sourcePackage.project.flags.find_by_flag_and_status( 'access', 'disable' )
      unless targetProject.flags.find_by_flag_and_status( 'access', 'disable' )
        sourcePackage.project.flags.delete(f)
        sourcePackage.project.store({:comment => 'project become public though release'})
        # patchinfos stay unpublished, it is anyway too late to test them now ...
      end
    end
  end

  def release_package_relink(link, request, targetPackageName, targetProject, tpkg)
    link.delete_attribute('project') # its a local link, project name not needed
    link.set_attribute('package', link.value(:package).gsub(/\..*/, '') + targetPackageName.gsub(/.*\./, '.')) # adapt link target with suffix
    link_xml = link.dump_xml
    answer = Suse::Backend.put "/source/#{URI.escape(targetProject.name)}/#{URI.escape(targetPackageName)}/_link?rev=repository&user=#{CGI.escape(User.current.login)}", link_xml
    md5 = Digest::MD5.hexdigest(link_xml)
                                     # commit with noservice parameneter
    upload_params = {
        :user => User.current.login,
        :cmd => 'commitfilelist',
        :noservice => '1',
        :comment => "Set link to #{targetPackageName} via maintenance_release request",
    }
    upload_params[:requestid] = request.id if request
    upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(targetPackageName)}"
    upload_path << Suse::Backend.build_query_from_hash(upload_params, [:user, :comment, :cmd, :noservice, :requestid])
    answer = Suse::Backend.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
    tpkg.sources_changed(answer)
  end

  def release_package_create_main_package(request, sourcePackage, targetPackageName, targetProject)
    basePackageName = targetPackageName.gsub(/\.[^\.]*$/, '')

    # only if package does not contain a _patchinfo file
    lpkg = nil
    if Package.exists_by_project_and_name(targetProject.name, basePackageName, follow_project_links: false)
      lpkg = Package.get_by_project_and_name(targetProject.name, basePackageName, use_source: false, follow_project_links: false)
    else
      lpkg = Package.new(:name => basePackageName, :title => sourcePackage.title, :description => sourcePackage.description)
      targetProject.packages << lpkg
      lpkg.store
    end
    upload_params = {
        :user => User.current.login,
        :rev => 'repository',
        :comment => "Set link to #{targetPackageName} via maintenance_release request",
    }
    upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(basePackageName)}/_link"
    upload_path << Suse::Backend.build_query_from_hash(upload_params, [:user, :rev])
    link = "<link package='#{targetPackageName}' cicount='copy' />\n"
    md5 = Digest::MD5.hexdigest(link)
    answer = Suse::Backend.put upload_path, link
    # commit
    upload_params[:cmd] = 'commitfilelist'
    upload_params[:noservice] = '1'
    upload_params[:requestid] = request.id if request
    upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(basePackageName)}"
    upload_path << Suse::Backend.build_query_from_hash(upload_params, [:user, :comment, :cmd, :noservice, :requestid])
    answer = Suse::Backend.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
    lpkg.sources_changed(answer)
  end

  def release_package_copy_sources(request, sourcePackage, targetPackageName, targetProject)
    # backend copy of current sources as full copy
    # that means the xsrcmd5 is different, but we keep the incident project anyway.
    cp_params = {
        :cmd => 'copy',
        :user => User.current.login,
        :oproject => sourcePackage.project.name,
        :opackage => sourcePackage.name,
        :comment => "Release from #{sourcePackage.project.name} / #{sourcePackage.name}",
        :expand => '1',
        :withvrev => '1',
        :noservice => '1',
    }
    cp_params[:requestid] = request.id if request
    cp_path = "/source/#{CGI.escape(targetProject.name)}/#{CGI.escape(targetPackageName)}"
    cp_path << Suse::Backend.build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :comment, :requestid, :expand, :withvrev, :noservice])
    Suse::Backend.post cp_path, nil
  end

  def copy_binaries(filterSourceRepository, sourcePackage, targetPackageName, targetProject, setrelease)
    sourcePackage.project.repositories.each do |sourceRepo|
      next if filterSourceRepository and filterSourceRepository != sourceRepo
      sourceRepo.release_targets.each do |releasetarget|
        #FIXME2.5: filter given release and/or target repos here
        sourceRepo.architectures.each do |arch|
          if releasetarget.target_repository.project == targetProject
            # get updateinfo id in case the source package comes from a maintenance project
            uID = get_updateinfo_id(sourcePackage, releasetarget.target_repository)
            copy_single_binary(arch, releasetarget, sourcePackage, sourceRepo, targetPackageName, uID,
                               setrelease, (releasetarget.trigger == 'maintenance'))
          end
        end
        # remove maintenance release trigger in source
        if releasetarget.trigger == 'maintenance'
          releasetarget.trigger = nil
          releasetarget.save!
          sourceRepo.project.store
        end
      end
    end
  end

  def copy_single_binary(arch, releasetarget, sourcePackage, sourceRepo, targetPackageName, updateinfoId, setrelease, resign)
    cp_params = {
        :cmd => 'copy',
        :oproject => sourcePackage.project.name,
        :opackage => sourcePackage.name,
        :orepository => sourceRepo.name,
        :user => User.current.login,
    }
    cp_params[:setupdateinfoid] = updateinfoId if updateinfoId
    cp_params[:setrelease] = setrelease if setrelease
    cp_params[:resign] = "1" if resign
    cp_path = "/build/#{CGI.escape(releasetarget.target_repository.project.name)}/#{URI.escape(releasetarget.target_repository.name)}/#{URI.escape(arch.name)}/#{URI.escape(targetPackageName)}"
    cp_path << Suse::Backend.build_query_from_hash(cp_params, [:cmd, :oproject, :opackage, :orepository, :setupdateinfoid, :resign, :setrelease])
    Suse::Backend.post cp_path, nil
  end

  def get_updateinfo_id(sourcePackage, targetRepo)
    return nil unless sourcePackage.is_patchinfo?

    # check for patch name inside of _patchinfo file
    xml = Patchinfo.new.read_patchinfo_xmlhash(sourcePackage)
    e = xml.elements("name")
    patchName = e ? e.first : ""

    mi = MaintenanceIncident.find_by_db_project_id(sourcePackage.project_id)
    return nil unless mi

    id_template = nil
    # check for a definition in maintenance project
    if a = mi.maintenance_db_project.find_attribute('OBS', 'MaintenanceIdTemplate')
      id_template = a.values[0].value
    end
    uID = mi.getUpdateinfoId(id_template, patchName)

    # expand a possible defined release target channel tag
    projectFilter = nil
    if p = sourcePackage.project.find_parent and p.is_maintenance?
      projectFilter = p.maintained_projects
    end
    channelTag="" # or strip away a possibly %T in any case
    if ct = ChannelTarget.find_by_repo(targetRepo, projectFilter)
       channelTag=ct.tag if ct.tag
    end
    return uID.gsub(/%T/,channelTag)
  end

  def create_package_container_if_missing(sourcePackage, targetPackageName, targetProject)
    tpkg = nil
    if Package.exists_by_project_and_name(targetProject.name, targetPackageName, follow_project_links: false)
      tpkg = Package.get_by_project_and_name(targetProject.name, targetPackageName, use_source: false, follow_project_links: false)
    else
      tpkg = Package.new(:name => targetPackageName, :title => sourcePackage.title, :description => sourcePackage.description)
      targetProject.packages << tpkg
      if sourcePackage.is_patchinfo?
        # publish patchinfos only
        tpkg.flags.create(:flag => 'publish', :status => 'enable')
      end
      tpkg.store
    end
    tpkg
  end

end
