module ReadAccessOfDeleted
  extend ActiveSupport::Concern

  # load last package meta file and just check if sourceaccess flag was used at all, no per user checking atm
  def validate_read_access_of_deleted_package(project, name)
    project_object = Project.find_by(name: project)
    if project_object
      raise Package::ReadSourceAccessError, "#{project}/#{name}" if project_object.disabled_for?('sourceaccess', nil, nil)
    else
      validate_read_access_of_deleted_project(project)
    end

    begin
      meta = Xmlhash.parse(Backend::Api::Sources::Package.meta(project, name, { deleted: 1 }))
    rescue Backend::NotFoundError
      raise Package::UnknownObjectError, "Package not found: #{project}/#{name}"
    end

    return true if User.admin_session?
    raise Package::ReadSourceAccessError, "#{project}/#{name}" if FlagHelper.xml_disabled_for?(meta, 'sourceaccess')
  end

  def validate_read_access_of_deleted_project(project)
    begin
      meta = Xmlhash.parse(Backend::Api::Sources::Project.meta(project, deleted: 1))
    rescue Backend::NotFoundError
      raise Project::UnknownObjectError, "Project not found: #{project}"
    end

    return true if User.admin_session?
    # FIXME: actually a per user checking would be more accurate here
    raise Project::UnknownObjectError, "Project not found: #{project}" if FlagHelper.xml_disabled_for?(meta, 'access')
  end
end
