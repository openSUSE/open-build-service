
module ValidationHelper

  def valid_project_name? name
    return true if name =~ /^\w[-_+\w\.:]*$/
    return false
  end

  def valid_package_name? name
    return true if name == "_patchinfo"
    return true if name == "_pattern"
    return true if name == "_project"
    return true if name == "_product"
    return true if name =~ /^_product:\w[-_+\w\.]*$/
    # obsolete, just for backward compatibility
    return true if name =~ /^_patchinfo:\w[-_+\w\.]*$/
    name =~ /^\w[-_+\w\.]*$/
  end

  # load last package meta file and just check if sourceaccess flag was used at all, no per user checking atm
  def validate_read_access_of_deleted_package(project, name)
    prj = DbProject.get_by_name project
    raise DbProject::ReadAccessError, "#{project}" if prj.disabled_for? 'access', nil, nil
    raise DbPackage::ReadSourceAccessError, "#{target_project_name}/#{target_package_name}" if prj.disabled_for? 'sourceaccess', nil, nil

    begin
      r = Suse::Backend.get("/source/#{CGI.escape(project)}/#{name}/_history?deleted=1&meta=1")
    rescue
      raise DbPackage::UnknownObjectError, "#{project}/#{name}"
    end

    data = ActiveXML::XMLNode.new(r.body.to_s)
    lastrev = nil
    data.each_revision {|rev| lastrev = rev}
    metapath = "/source/#{CGI.escape(project)}/#{name}/_meta"
    if lastrev
      srcmd5 = lastrev.value('srcmd5')
      metapath += "?rev=#{srcmd5}" # only add revision if package has some
    end

    r = Suse::Backend.get(metapath)
    raise DbPackage::UnknownObjectError, "#{project}/#{name}" unless r
    dpkg = Package.new(r.body)
    raise DbPackage::UnknownObjectError, "#{project}/#{name}" unless dpkg
    raise DbPackage::ReadSourceAccessError, "#{project}/#{name}" if dpkg.disabled_for? 'sourceaccess' and not @http_user.is_admin?
  end

  def validate_visibility_of_deleted_project(project)
    begin
      r = Suse::Backend.get("/source/#{CGI.escape(project)}/_project/_history?deleted=1&meta=1")
    rescue
      raise DbProject::UnknownObjectError, "#{project}"
    end

    data = ActiveXML::XMLNode.new(r.body.to_s)
    lastrev = nil
    data.each_revision {|rev| lastrev = rev}
    raise DbProject::UnknownObjectError, "#{project}" unless lastrev

    metapath = "/source/#{CGI.escape(project)}/_project/_meta?rev=#{lastrev.value('srcmd5')}&deleted=1"
    r = Suse::Backend.get(metapath)
    dprj = Project.new(r.body)
    #FIXME: actually a per user checking would be more accurate here
    raise DbProject::UnknownObjectError, "#{project}" if dprj.nil? or (dprj.disabled_for? 'access' and not @http_user.is_admin?)
  end

end
