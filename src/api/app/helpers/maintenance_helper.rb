include ValidationHelper

module MaintenanceHelper
  class MissingAction < APIException
    setup 400, 'The request contains no actions. Submit requests without source changes may have skipped!'
  end

  class MultipleUpdateInfoTemplate < APIException; end

  def _release_product(sourcePackage, targetProject, action)
    productPackage = Package.find_by_project_and_name sourcePackage.project.name, "_product"
    # create package container, if missing
    tpkg = create_package_container_if_missing(productPackage, "_product", targetProject)
    # copy sources
    release_package_copy_sources(action, productPackage, "_product", targetProject)
    tpkg.project.update_product_autopackages
    tpkg.sources_changed
  end

  def _release_package(sourcePackage, targetProject, targetPackageName, action, relink)
    # create package container, if missing
    tpkg = create_package_container_if_missing(sourcePackage, targetPackageName, targetProject)

    link = nil
    if relink
      # detect local links
      begin
        link = sourcePackage.source_file('_link')
        link = ActiveXML::Node.new(link)
      rescue ActiveXML::Transport::Error
        link = nil
      end
    end
    if link && (link.value(:project).nil? || link.value(:project) == sourcePackage.project.name)
      release_package_relink(link, action, targetPackageName, targetProject, tpkg)
    else
      # copy sources
      release_package_copy_sources(action, sourcePackage, targetPackageName, targetProject)
      tpkg.sources_changed
    end
  end

  def release_package(sourcePackage, target, targetPackageName,
                      filterSourceRepository = nil, action = nil, setrelease = nil, manual = nil)
    if target.kind_of? Repository
      targetProject = target.project
    else
      # project
      targetProject = target
    end
    targetProject.check_write_access!

    if sourcePackage.name.starts_with?("_product:") && targetProject.packages.where(name: "_product").count>0
      # a master _product container exists, so we need to copy all sources
      _release_product(sourcePackage, targetProject, action)
    else
      _release_package(sourcePackage, targetProject, targetPackageName, action, manual ? nil : true)
    end

    # copy binaries
    if target.kind_of? Repository
      uIDs = copy_binaries_to_repository(filterSourceRepository, sourcePackage, target, targetPackageName, setrelease)
    else
      uIDs = copy_binaries(filterSourceRepository, sourcePackage, targetPackageName, targetProject, setrelease)
    end

    # create or update main package linking to incident package
    unless sourcePackage.is_patchinfo? || manual
      release_package_create_main_package(action.bs_request, sourcePackage, targetPackageName, targetProject)
    end

    # publish incident if source is read protect, but release target is not. assuming it got public now.
    f = sourcePackage.project.flags.find_by_flag_and_status( 'access', 'disable' )
    if f
      unless targetProject.flags.find_by_flag_and_status( 'access', 'disable' )
        sourcePackage.project.flags.delete(f)
        sourcePackage.project.store({comment: 'project becomes public on release action'})
        # patchinfos stay unpublished, it is anyway too late to test them now ...
      end
    end

    uIDs
  end

  def release_package_relink(link, action, targetPackageName, targetProject, tpkg)
    link.delete_attribute('project') # its a local link, project name not needed
    link.set_attribute('package', link.value(:package).gsub(/\..*/, '') + targetPackageName.gsub(/.*\./, '.')) # adapt link target with suffix
    link_xml = link.dump_xml
    # rubocop:disable Metrics/LineLength
    Suse::Backend.put "/source/#{URI.escape(targetProject.name)}/#{URI.escape(targetPackageName)}/_link?rev=repository&user=#{CGI.escape(User.current.login)}", link_xml
    # rubocop:enable Metrics/LineLength
    md5 = Digest::MD5.hexdigest(link_xml)
    # commit with noservice parameter
    upload_params = {
      user:      User.current.login,
      cmd:       "commitfilelist",
      noservice: "1",
      comment:   "Set local link to #{targetPackageName} via maintenance_release request"
    }
    upload_params[:requestid] = action.bs_request.number if action
    upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(targetPackageName)}"
    upload_path << Suse::Backend.build_query_from_hash(upload_params, [:user, :comment, :cmd, :noservice, :requestid])
    answer = Suse::Backend.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
    tpkg.sources_changed(dir_xml: answer)
  end

  def release_package_create_main_package(request, sourcePackage, targetPackageName, targetProject)
    basePackageName = targetPackageName.gsub(/\.[^\.]*$/, '')

    # only if package does not contain a _patchinfo file
    lpkg = nil
    if Package.exists_by_project_and_name(targetProject.name, basePackageName, follow_project_links: false)
      lpkg = Package.get_by_project_and_name(targetProject.name, basePackageName, use_source: false, follow_project_links: false)
    else
      lpkg = Package.new(name: basePackageName, title: sourcePackage.title, description: sourcePackage.description)
      targetProject.packages << lpkg
      lpkg.store
    end
    upload_params = {
      user:    User.current.login,
      rev:     "repository",
      comment: "Set link to #{targetPackageName} via maintenance_release request"
    }
    upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(basePackageName)}/_link"
    upload_path << Suse::Backend.build_query_from_hash(upload_params, [:user, :rev])
    link = "<link package='#{targetPackageName}' cicount='copy' />\n"
    md5 = Digest::MD5.hexdigest(link)
    Suse::Backend.put upload_path, link
    # commit
    upload_params[:cmd] = 'commitfilelist'
    upload_params[:noservice] = '1'
    upload_params[:requestid] = request.number if request
    upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(basePackageName)}"
    upload_path << Suse::Backend.build_query_from_hash(upload_params, [:user, :comment, :cmd, :noservice, :requestid])
    answer = Suse::Backend.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
    lpkg.sources_changed(dir_xml: answer)
  end

  def release_package_copy_sources(action, sourcePackage, targetPackageName, targetProject)
    # backend copy of current sources as full copy
    # that means the xsrcmd5 is different, but we keep the incident project anyway.
    cp_params = {
      cmd:            "copy",
      user:           User.current.login,
      oproject:       sourcePackage.project.name,
      opackage:       sourcePackage.name,
      comment:        "Release from #{sourcePackage.project.name} / #{sourcePackage.name}",
      expand:         "1",
      withvrev:       "1",
      noservice:      "1",
      withacceptinfo: "1"
    }
    cp_params[:requestid] = action.bs_request.number if action
    if targetProject.is_maintenance_release? && sourcePackage.is_link?
      # no permission check here on purpose
      if sourcePackage.linkinfo['project'] == targetProject.name &&
         sourcePackage.linkinfo['package'] == targetPackageName.gsub(/\.[^\.]*$/, '')
        # link target is equal to release target. So we freeze our link.
        cp_params[:freezelink] = 1
      end
    end
    cp_path = "/source/#{CGI.escape(targetProject.name)}/#{CGI.escape(targetPackageName)}"
    cp_path << Suse::Backend.build_query_from_hash(cp_params, [:cmd, :user, :oproject,
                                                               :opackage, :comment, :requestid,
                                                               :expand, :withvrev, :noservice,
                                                               :freezelink, :withacceptinfo])
    result = Suse::Backend.post(cp_path)
    result = Xmlhash.parse(result.body)
    action.set_acceptinfo(result["acceptinfo"]) if action
  end

  def copy_binaries(filterSourceRepository, sourcePackage, targetPackageName, targetProject, setrelease)
    updateIDs=[]
    sourcePackage.project.repositories.each do |sourceRepo|
      next if filterSourceRepository && filterSourceRepository != sourceRepo
      sourceRepo.release_targets.each do |releasetarget|
        # FIXME: filter given release and/or target repos here
        if releasetarget.target_repository.project == targetProject
          uID = copy_binaries_to_repository(sourceRepo, sourcePackage, releasetarget.target_repository, targetPackageName, setrelease)
	  updateIDs << uID if uID
        end
        # remove maintenance release trigger in source
        if releasetarget.trigger == 'maintenance'
          releasetarget.trigger = nil
          releasetarget.save!
          sourceRepo.project.store
        end
      end
    end
    updateIDs
  end

  def copy_binaries_to_repository(sourceRepository, sourcePackage, targetRepo, targetPackageName, setrelease)
    uID = get_updateinfo_id(sourcePackage, targetRepo)
    sourceRepository.architectures.each do |arch|
      # get updateinfo id in case the source package comes from a maintenance project
      copy_single_binary(arch, targetRepo, sourcePackage, sourceRepository, targetPackageName, uID, setrelease)
    end
    uID
  end

  def copy_single_binary(arch, target_repository, sourcePackage, sourceRepo, targetPackageName, updateinfoId, setrelease)
    cp_params = {
      cmd:         "copy",
      oproject:    sourcePackage.project.name,
      opackage:    sourcePackage.name,
      orepository: sourceRepo.name,
      user:        User.current.login,
      multibuild:  "1",
      resign:      "1"
    }
    cp_params[:setupdateinfoid] = updateinfoId if updateinfoId
    cp_params[:setrelease] = setrelease if setrelease
    # rubocop:disable Metrics/LineLength
    cp_path = "/build/#{CGI.escape(target_repository.project.name)}/#{URI.escape(target_repository.name)}/#{URI.escape(arch.name)}/#{URI.escape(targetPackageName)}"
    # rubocop:enable Metrics/LineLength
    cp_path << Suse::Backend.build_query_from_hash(cp_params, [:cmd, :oproject, :opackage,
                                                               :orepository, :setupdateinfoid,
                                                               :resign, :setrelease, :multibuild])
    Suse::Backend.post cp_path
  end

  def get_updateinfo_id(sourcePackage, targetRepo)
    return nil unless sourcePackage.is_patchinfo?

    # check for patch name inside of _patchinfo file
    xml = Patchinfo.new.read_patchinfo_xmlhash(sourcePackage)
    e = xml.elements("name")
    patchName = e ? e.first : ""

    mi = MaintenanceIncident.find_by_db_project_id(sourcePackage.project_id)
    return nil unless mi

    id_template = "%Y-%C"
    # check for a definition in maintenance project
    a = mi.maintenance_db_project.find_attribute('OBS', 'MaintenanceIdTemplate')
    if a
      id_template = a.values[0].value
    end

    # expand a possible defined update info template in release target of channel
    projectFilter = nil
    prj = sourcePackage.project.parent
    if prj && prj.is_maintenance?
      projectFilter = prj.maintained_projects.map{|mp| mp.project}
    end
    # prefer a channel in the source project to avoid double hits exceptions
    cts = ChannelTarget.find_by_repo(targetRepo, [sourcePackage.project])
    cts = ChannelTarget.find_by_repo(targetRepo, projectFilter) unless cts.any?
    first_ct = cts.first
    unless cts.all?{|c| c.id_template == first_ct.id_template}
      msg = cts.map{|cti| "#{cti.channel.package.project.name}/#{cti.channel.package.name}"}.join(", ")
      raise MultipleUpdateInfoTemplate.new "Multiple channel targets found in #{msg} for repository #{targetRepo.project.name}/#{targetRepo.name}"
    end
    id_template = cts.first.id_template if cts.first && cts.first.id_template

    uID = mi.getUpdateinfoId(id_template, patchName)
    uID
  end

  def create_package_container_if_missing(sourcePackage, targetPackageName, targetProject)
    tpkg = nil
    if Package.exists_by_project_and_name(targetProject.name, targetPackageName, follow_project_links: false)
      tpkg = Package.get_by_project_and_name(targetProject.name, targetPackageName, use_source: false, follow_project_links: false)
    else
      tpkg = Package.new(name: targetPackageName, title: sourcePackage.title, description: sourcePackage.description)
      targetProject.packages << tpkg
      if sourcePackage.is_patchinfo?
        # publish patchinfos only
        tpkg.flags.create(flag: 'publish', status: 'enable')
      end
      tpkg.store
    end
    tpkg
  end

  def import_channel(channel, pkg, targetRepo = nil)
    channel = REXML::Document.new(channel)

    if targetRepo
      channel.elements['/channel'].add_element 'target', {
        "project"    => targetRepo.project.name,
        "repository" => targetRepo.name
      }
    end

    # replace all project definitions with update projects, if they are defined
    [ '//binaries', '//binary' ].each do |bin|
      channel.get_elements(bin).each do |b|
        attrib = b.attributes.get_attribute('project')
        prj = Project.get_by_name(attrib.to_s) if attrib
        if defined?(prj) && prj
          a = prj.find_attribute('OBS', 'UpdateProject')
          if a && a.values[0]
            b.attributes["project"] = a.values[0]
          end
        end
      end
    end

    query = { user: User.current ? User.current.login : User.nobody_login }
    query[:comment] = "channel import function"
    Suse::Backend.put_source(pkg.source_path('_channel', query), channel.to_s)

    pkg.sources_changed
    # enforce updated channel list in database:
    pkg.update_backendinfo
  end

  def instantiate_container(project, opackage, opts = {})
    opkg = opackage.origin_container
    pkg_name = opkg.name
    if opkg.is_a?(Package) && opkg.project.is_maintenance_release?
      # strip incident suffix
      pkg_name = opkg.name.gsub(/\.[^\.]*$/, '')
    end

    # target packages must not exist yet
    if Package.exists_by_project_and_name(project.name, pkg_name, follow_project_links: false)
      raise PackageAlreadyExists "package #{opkg.name} already exists"
    end
    opkg.find_project_local_linking_packages.each do |p|
      lpkg_name = p.name
      if p.is_a?(Package) && p.project.is_maintenance_release?
        # strip incident suffix
        lpkg_name = p.name.gsub(/\.[^\.]*$/, '')
      end
      if Package.exists_by_project_and_name(project.name, lpkg_name, follow_project_links: false)
        raise PackageAlreadyExists "package #{p.name} already exists"
      end
    end

    pkg = project.packages.create(name: pkg_name, title: opkg.title, description: opkg.description)
    pkg.store

    arguments="&noservice=1"
    arguments << "&requestid=" << opts[:request].number.to_s if opts[:request]
    arguments << "&comment=" << CGI.escape(opts[:comment]) if opts[:comment]
    if opts[:makeoriginolder]
      # rubocop:disable Metrics/LineLength
      # versioned copy
      path = pkg.source_path + "?cmd=copy&withvrev=1&oproject=#{CGI.escape(opkg.project.name)}&opackage=#{CGI.escape(opkg.name)}#{arguments}&user=#{CGI.escape(User.current.login)}&comment=initialize+package"
      # rubocop:enable Metrics/LineLength
      if Package.exists_by_project_and_name(project.name, opkg.name, allow_remote_packages: true)
        # a package exists via project link, make it older in any case
        path << "+and+make+source+instance+older&makeoriginolder=1"
      end
      Suse::Backend.post path
    else
      # rubocop:disable Metrics/LineLength
      # simple branch
      Suse::Backend.post pkg.source_path + "?cmd=branch&oproject=#{CGI.escape(opkg.project.name)}&opackage=#{CGI.escape(opkg.name)}#{arguments}&user=#{CGI.escape(User.current.login)}&comment=initialize+package+as+branch"
      # rubocop:enable Metrics/LineLength
    end
    pkg.sources_changed

    # and create the needed local links
    opkg.find_project_local_linking_packages.each do |p|
      lpkg_name = p.name
      if p.is_a?(Package) && p.project.is_maintenance_release?
        # strip incident suffix
        lpkg_name = p.name.gsub(/\.[^\.]*$/, '')
        # skip the base links
        next if lpkg_name == p.name
      end
      # create container
      unless project.packages.where(name: lpkg_name).exists?
        lpkg = project.packages.create(name: lpkg_name, title: p.title, description: p.description)
        lpkg.store
      end

      # rubocop:disable Metrics/LineLength
      # copy project local linked packages
      Suse::Backend.post "/source/#{pkg.project.name}/#{lpkg.name}?cmd=copy&oproject=#{CGI.escape(p.project.name)}&opackage=#{CGI.escape(p.name)}#{arguments}&user=#{CGI.escape(User.current.login)}"
      # rubocop:enable Metrics/LineLength
      # and fix the link
      ret = ActiveXML::Node.new(lpkg.source_file('_link'))
      ret.delete_attribute('project') # its a local link, project name not needed
      ret.set_attribute('package', pkg.name)
      Suse::Backend.put lpkg.source_path('_link', user: User.current.login), ret.dump_xml
      lpkg.sources_changed
    end
  end
end
