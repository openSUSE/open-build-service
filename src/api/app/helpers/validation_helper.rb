
module ValidationHelper

  def valid_project_name? name
    return true if name =~ /\A\w[-+\w\.:]*\z/
    return false
  end

  def valid_package_name? name
    return true if name == "_patchinfo"
    return true if name == "_pattern"
    return true if name == "_project"
    return true if name == "_product"
    return true if name =~ /\A_product:\w[-+\w\.]*\z/
    # obsolete, just for backward compatibility
    return true if name =~ /\A_patchinfo:\w[-+\w\.]*\z/
    name =~ /\A\w[-+\w\.]*\z/
  end

  # load last package meta file and just check if sourceaccess flag was used at all, no per user checking atm
  def validate_read_access_of_deleted_package(project, name)
    prj = Project.get_by_name project
    raise Project::ReadAccessError, "#{project}" if prj.disabled_for? 'access', nil, nil
    raise Package::ReadSourceAccessError, "#{target_project_name}/#{target_package_name}" if prj.disabled_for? 'sourceaccess', nil, nil

    begin
      r = Suse::Backend.get("/source/#{CGI.escape(project)}/#{name}/_history?deleted=1&meta=1")
    rescue
      raise Package::UnknownObjectError, "#{project}/#{name}"
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
    raise Package::UnknownObjectError, "#{project}/#{name}" unless r
    return true if @http_user.is_admin?
    if FlagHelper.xml_disabled_for?(Xmlhash.parse(r.body), 'sourceaccess')
      raise Package::ReadSourceAccessError, "#{project}/#{name}"
    end
    return true
  end

  def validate_visibility_of_deleted_project(project)
    begin
      r = Suse::Backend.get("/source/#{CGI.escape(project)}/_project/_history?deleted=1&meta=1")
    rescue
      raise Project::UnknownObjectError, "#{project}"
    end

    data = ActiveXML::XMLNode.new(r.body.to_s)
    lastrev = nil
    data.each_revision {|rev| lastrev = rev}
    raise Project::UnknownObjectError, "#{project}" unless lastrev

    metapath = "/source/#{CGI.escape(project)}/_project/_meta?rev=#{lastrev.value('srcmd5')}&deleted=1"
    r = Suse::Backend.get(metapath)
    raise Project::UnknownObjectError unless r
    return true if @http_user.is_admin?
    if FlagHelper.xml_disabled_for?(Xmlhash.parse(r.body), 'access')
      #FIXME: actually a per user checking would be more accurate here
      raise Project::UnknownObjectError, "#{project}"
    end
  end

end
