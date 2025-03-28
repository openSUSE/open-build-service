module MaintenanceHelper
  include ValidationHelper

  class MissingAction < APIError
    setup 400, 'The request contains no actions. Submit requests without source changes may have skipped!'
  end

  class MultipleUpdateInfoTemplate < APIError; end

  def _release_product(source_package, target_project, action)
    product_package = Package.find_by_project_and_name(source_package.project.name, '_product')
    # create package container, if missing
    tpkg = create_package_container_if_missing(product_package, '_product', target_project)
    # copy sources
    release_package_copy_sources(action, product_package, '_product', target_project)
    tpkg.project.update_product_autopackages
    tpkg.sources_changed
  end

  def _release_package(source_package, target_project, target_package_name, action, relink)
    # create package container, if missing
    tpkg = create_package_container_if_missing(source_package, target_package_name, target_project)

    links_to_source = false
    if relink
      # detect local links
      begin
        link = source_package.source_file('_link')
        link = Nokogiri::XML(link, &:strict).root
        links_to_source = link['project'].nil? || link['project'] == source_package.project.name
      rescue Backend::Error
        # Ignore this exception on purpose
      end
    end
    if links_to_source
      release_package_relink(link, action, target_package_name, target_project, tpkg)
    else
      # copy sources
      release_package_copy_sources(action, source_package, target_package_name, target_project)
      tpkg.sources_changed
    end
  end

  def release_package(source_package, target, target_package_name, opts = {})
    filter_source_repository = opts[:filter_source_repository]
    filter_architecture      = opts[:filter_architecture]
    multibuild_container     = opts[:multibuild_container]
    action                   = opts[:action]
    setrelease               = opts[:setrelease]
    manual                   = opts[:manual]
    comment                  = opts[:comment]

    comment = "Release request #{action.bs_request.number}" if action && comment.nil?

    target_project = if target.is_a?(Repository)
                       target.project
                     else
                       # project
                       target
                     end
    target_project.check_write_access!
    # lock the scheduler
    target_project.suspend_scheduler(comment)

    if source_package.name.starts_with?('_product:') && target_project.packages.where(name: '_product').count.positive?
      # a master _product container exists, so we need to copy all sources
      _release_product(source_package, target_project, action)
    else
      _release_package(source_package, target_project, target_package_name, action, manual ? nil : true)
    end

    # copy binaries
    u_ids = if target.is_a?(Repository)
              copy_binaries_to_repository(filter_source_repository, filter_architecture, source_package, target, target_package_name, multibuild_container, setrelease)
            else
              copy_binaries(filter_source_repository, filter_architecture, source_package, target_package_name, target_project, multibuild_container, setrelease, manual)
            end

    # create or update main package linking to incident package
    release_package_create_main_package(action.bs_request, source_package, target_package_name, target_project) unless source_package.patchinfo? || manual

    # publish incident if source is read protect, but release target is not. assuming it got public now.
    f = source_package.project.flags.find_by_flag_and_status('access', 'disable')
    if f && !target_project.flags.find_by_flag_and_status('access', 'disable')
      source_package.project.flags.delete(f)
      source_package.project.store(comment: 'project becomes public on release action')
      # patchinfos stay unpublished, it is anyway too late to test them now ...
    end

    # release the scheduler lock
    target_project.resume_scheduler(comment)

    u_ids
  end

  def release_package_relink(link, action, target_package_name, target_project, tpkg)
    link.remove_attribute('project') # its a local link, project name not needed
    link['package'] = link['package'].gsub(/\..*/, '') + target_package_name.gsub(/.*\./, '.') # adapt link target with suffix
    link_xml = link.to_xml
    Backend::Connection.put Addressable::URI.escape("/source/#{target_project.name}/#{target_package_name}/_link?rev=repository&user=#{User.session!.login}"), link_xml

    md5 = Digest::MD5.hexdigest(link_xml)
    # commit with noservice parameter
    upload_params = {
      user: User.session!.login,
      cmd: 'commitfilelist',
      noservice: '1',
      comment: "Set local link to #{target_package_name} via maintenance_release request"
    }
    upload_params[:requestid] = action.bs_request.number if action
    upload_path = Addressable::URI.escape("/source/#{target_project.name}/#{target_package_name}")
    upload_path << Backend::Connection.build_query_from_hash(upload_params, %i[user comment cmd noservice requestid])
    answer = Backend::Connection.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
    tpkg.sources_changed(dir_xml: answer)
  end

  def release_package_create_main_package(request, source_package, target_package_name, target_project)
    base_package_name = target_package_name.gsub(/\.[^.]*$/, '')

    # only if package does not contain a _patchinfo file
    lpkg = nil
    if Package.exists_by_project_and_name(target_project.name, base_package_name, follow_project_links: false)
      lpkg = Package.get_by_project_and_name(target_project.name, base_package_name, use_source: false, follow_project_links: false)
    else
      lpkg = Package.new(name: base_package_name, title: source_package.title, description: source_package.description)
      target_project.packages << lpkg
      lpkg.store
    end
    upload_params = {
      user: User.session!.login,
      rev: 'repository',
      comment: "Set link to #{target_package_name} via maintenance_release request"
    }
    upload_path = Addressable::URI.escape("/source/#{target_project.name}/#{base_package_name}/_link")
    upload_path << Backend::Connection.build_query_from_hash(upload_params, %i[user rev])
    link = "<link package='#{target_package_name}' cicount='copy' />\n"
    md5 = Digest::MD5.hexdigest(link)
    Backend::Connection.put upload_path, link
    # commit
    upload_params[:cmd] = 'commitfilelist'
    upload_params[:noservice] = '1'
    upload_params[:requestid] = request.number if request
    upload_path = Addressable::URI.escape("/source/#{target_project.name}/#{base_package_name}")
    upload_path << Backend::Connection.build_query_from_hash(upload_params, %i[user comment cmd noservice requestid])
    answer = Backend::Connection.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
    lpkg.sources_changed(dir_xml: answer)
  end

  def release_package_copy_sources(action, source_package, target_package_name, target_project)
    # backend copy of current sources as full copy
    # that means the xsrcmd5 is different, but we keep the incident project anyway.
    cp_params = {
      cmd: 'copy',
      user: User.session!.login,
      oproject: source_package.project.name,
      opackage: source_package.name,
      comment: "Release from #{source_package.project.name} / #{source_package.name}",
      expand: '1',
      withvrev: '1',
      noservice: '1',
      withacceptinfo: '1'
    }
    cp_params[:requestid] = action.bs_request.number if action
    # no permission check here on purpose
    if target_project.maintenance_release? && source_package.link? && source_package.linkinfo['project'] == target_project.name &&
       source_package.linkinfo['package'] == target_package_name.gsub(/\.[^.]*$/, '')
      # link target is equal to release target. So we freeze our link.
      cp_params[:freezelink] = 1
    end
    cp_path = Addressable::URI.escape("/source/#{target_project.name}/#{target_package_name}")
    cp_path << Backend::Connection.build_query_from_hash(cp_params, %i[cmd user oproject
                                                                       opackage comment requestid
                                                                       expand withvrev noservice
                                                                       freezelink withacceptinfo])
    result = Backend::Connection.post(cp_path)
    result = Xmlhash.parse(result.body)
    action.fill_acceptinfo(result['acceptinfo']) if action
  end

  def copy_binaries(filter_source_repository, filter_architecture, source_package, target_package_name,
                    target_project, multibuild_container, setrelease, manual)
    update_ids = []
    source_package.project.repositories.each do |source_repo|
      next if filter_source_repository && filter_source_repository != source_repo

      source_repo.release_targets.each do |releasetarget|
        next if manual && releasetarget.trigger != 'manual'

        if releasetarget.target_repository.project == target_project
          u_id = copy_binaries_to_repository(source_repo, filter_architecture, source_package, releasetarget.target_repository,
                                             target_package_name, multibuild_container, setrelease)
          update_ids << u_id if u_id
        end
        # remove maintenance release trigger in source
        next unless releasetarget.trigger == 'maintenance'

        releasetarget.trigger = nil
        releasetarget.save!
        source_repo.project.store
      end
    end
    update_ids
  end

  def copy_binaries_to_repository(source_repository, filter_architecture, source_package, target_repo, target_package_name,
                                  multibuild_container, setrelease)
    # get updateinfo id in case the source package comes from a maintenance project
    u_id = get_updateinfo_id(source_package, target_repo)
    source_package_name = source_package.name
    if multibuild_container.present?
      source_package_name << ':' << multibuild_container
      target_package_name = target_package_name.gsub(/:.*/, '') << ':' << multibuild_container
    end
    source_repository.architectures.each do |arch|
      # user architecture filter
      next if filter_architecture.present? && arch.name != filter_architecture

      # skip automatically because target lacks the architecture
      next unless target_repo.architectures.include?(arch)

      copy_single_binary(arch, target_repo, source_package.project.name, source_package_name,
                         source_repository, target_package_name, u_id, setrelease)
    end
    u_id
  end

  def copy_single_binary(arch, target_repository, source_project_name, source_package_name, source_repo,
                         target_package_name, update_info_id, setrelease)
    cp_params = {
      cmd: 'copy',
      oproject: source_project_name,
      opackage: source_package_name,
      orepository: source_repo.name,
      user: User.session!.login,
      resign: '1'
    }
    cp_params[:setupdateinfoid] = update_info_id if update_info_id
    cp_params[:setrelease] = setrelease if setrelease
    cp_params[:multibuild] = '1' unless source_package_name.include?(':')
    cp_path = Addressable::URI.escape("/build/#{target_repository.project.name}/#{target_repository.name}/#{arch.name}/#{target_package_name}")

    cp_path << Backend::Connection.build_query_from_hash(cp_params, %i[cmd oproject opackage
                                                                       orepository setupdateinfoid
                                                                       resign setrelease multibuild])
    Backend::Connection.post cp_path
  end

  def get_updateinfo_id(source_package, target_repo)
    return unless source_package.patchinfo?

    # check for patch name inside of _patchinfo file
    xml = Patchinfo.new.read_patchinfo_xmlhash(source_package)
    e = xml.elements('name')
    patch_name = e ? e.first : ''

    mi = MaintenanceIncident.find_by_db_project_id(source_package.project_id)
    return unless mi

    id_template = '%Y-%C'
    # check for a definition in maintenance project
    a = mi.maintenance_db_project.find_attribute('OBS', 'MaintenanceIdTemplate')
    id_template = a.values[0].value if a

    # expand a possible defined update info template in release target of channel
    project_filter = nil
    prj = source_package.project.parent
    project_filter = prj.maintained_projects.map(&:project) if prj && prj.maintenance?
    # prefer a channel in the source project to avoid double hits exceptions
    cts = ChannelTarget.find_by_repo(target_repo, [source_package.project])
    cts = ChannelTarget.find_by_repo(target_repo, project_filter) unless cts.any?
    first_ct = cts.first
    unless cts.all? { |c| c.id_template == first_ct.id_template }
      msg = cts.map { |cti| "#{cti.channel.package.project.name}/#{cti.channel.package.name}" }.join(', ')
      raise MultipleUpdateInfoTemplate, "Multiple channel targets found in #{msg} for repository #{target_repo.project.name}/#{target_repo.name}"
    end
    id_template = cts.first.id_template if cts.first && cts.first.id_template

    mi.get_updateinfo_id(id_template, patch_name)
  end

  def create_package_container_if_missing(source_package, target_package_name, target_project)
    tpkg = nil
    if Package.exists_by_project_and_name(target_project.name, target_package_name, follow_project_links: false)
      tpkg = Package.get_by_project_and_name(target_project.name, target_package_name, use_source: false, follow_project_links: false)
    else
      tpkg = Package.new(name: target_package_name,
                         releasename: source_package.releasename,
                         title: source_package.title,
                         description: source_package.description)
      target_project.packages << tpkg
      if source_package.patchinfo?
        # publish patchinfos only
        tpkg.flags.create(flag: 'publish', status: 'enable')
      end
      tpkg.store
    end
    tpkg
  end

  def import_channel(channel, pkg, target_repo = nil)
    channel = REXML::Document.new(channel)

    channel.elements['/channel'].add_element 'target', 'project' => target_repo.project.name, 'repository' => target_repo.name if target_repo

    # replace all project definitions with update projects, if they are defined
    ['//binaries', '//binary'].each do |bin|
      channel.get_elements(bin).each do |b|
        attrib = b.attributes.get_attribute('project')
        prj = Project.get_by_name(attrib.to_s) if attrib
        if defined?(prj) && prj
          a = prj.find_attribute('OBS', 'UpdateProject')
          b.attributes['project'] = a.values[0] if a && a.values[0]
        end
      end
    end

    query = { user: User.session!.login }
    query[:comment] = 'channel import function'
    Backend::Connection.put(pkg.source_path('_channel', query), channel.to_s)

    pkg.sources_changed
    # enforce updated channel list in database:
    pkg.update_backendinfo
  end

  def instantiate_container(project, opackage, opts = {})
    opkg = opackage.origin_container
    pkg_name = opkg_name = opkg.name
    if opkg.is_a?(Package) && opkg.project.maintenance_release?
      # strip incident suffix
      pkg_name = opkg.name.gsub(/\.[^.]*$/, '')
    end

    # target packages must not exist yet
    raise PackageAlreadyExists, "package #{opkg.name} already exists" if Package.exists_by_project_and_name(project.name, pkg_name, follow_project_links: false)

    local_linked_packages = {}
    opkg.find_project_local_linking_packages.each do |p|
      lpkg_name = p.name
      if opkg_name != pkg_name && p.is_a?(Package) && p.project.maintenance_release?
        # strip incident suffix
        lpkg_name = p.name.gsub(/\.[^.]*$/, '')
        # skip the base links
        next if lpkg_name == p.name
      end
      raise PackageAlreadyExists, "package #{p.name} already exists" if Package.exists_by_project_and_name(project.name, lpkg_name, follow_project_links: false)

      # only create local link when it also exists in source project
      # avoid cases with dot's in the package name (eg. go1.19)
      local_linked_packages[lpkg_name] = p if Package.exists_by_project_and_name(p.project.name, lpkg_name)
    end

    pkg = project.packages.create(name: pkg_name, title: opkg.title, description: opkg.description)
    pkg.store

    copyopts = { noservice: '1' }
    copyopts[:requestid] = opts[:request].number.to_s if opts[:request]
    copyopts[:comment] << CGI.escape(opts[:comment]) if opts[:comment]
    # makeoriginolder is a poorly choosen name meanwhile, because it is no longer used in backend
    # call. We should replace it by a "service_pack" project kind or attribute.
    if opts[:makeoriginolder]
      # versioned copy
      copyopts[:cmd] = 'copy'
      copyopts[:instantiate] = '1'
      copyopts[:withvrev]    = '1'
      copyopts[:vrevbump]    = '2'
      copyopts[:oproject]    = opkg.project.name
      copyopts[:opackage]    = opkg.name
      copyopts[:user]        = User.session!.login
      copyopts[:comment]     = 'initialize package'
    else
      # simple branch
      copyopts[:cmd] = 'branch'
      copyopts[:oproject] = opkg.project.name
      copyopts[:opackage] = opkg.name
      copyopts[:user]     = User.session!.login
      copyopts[:comment]  = 'initialize package as branch'
    end
    path = pkg.source_path
    path << Backend::Connection.build_query_from_hash(copyopts, %i[user comment cmd noservice requestid
                                                                   makeoriginolder withvrev vrevbump
                                                                   instantiate oproject opackage])
    Backend::Connection.post(path)
    pkg.sources_changed

    # and create the needed local links
    local_linked_packages.each do |lpkg_name, p|
      # create container
      lpkg = project.packages.create(name: lpkg_name, title: p.title, description: p.description)
      lpkg.store

      # copy project local linked packages
      path = lpkg.source_path
      copyopts[:cmd] = 'copy'
      copyopts[:oproject] = p.project.name
      copyopts[:opackage] = p.name
      path << Backend::Connection.build_query_from_hash(copyopts, %i[user cmd noservice requestid
                                                                     oproject opackage])
      Backend::Connection.post path
      # and fix the link
      link_xml = Nokogiri::XML(lpkg.source_file('_link'), &:strict).root
      link_xml.remove_attribute('project') # its a local link, project name not needed
      link_xml['package'] = pkg.name
      Backend::Connection.put lpkg.source_path('_link', user: User.session!.login), link_xml.to_xml
      lpkg.sources_changed
    end
  end
end
