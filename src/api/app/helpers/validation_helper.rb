require 'api_exception'

module ValidationHelper
  class InvalidProjectNameError < APIError
  end

  class InvalidPackageNameError < APIError
  end

  def valid_project_name?(name)
    Project.valid_name?(name)
  end

  def valid_project_name!(project_name)
    raise InvalidProjectNameError, "invalid project name '#{project_name}'" unless valid_project_name?(project_name)
  end

  def valid_package_name?(name)
    Package.valid_name?(name)
  end

  def valid_package_name!(package_name)
    raise InvalidPackageNameError, "invalid package name '#{package_name}'" unless valid_package_name?(package_name)
  end

  def valid_multibuild_package_name!(package_name)
    raise InvalidPackageNameError, "invalid package name '#{package_name}'" unless Package.valid_multibuild_name?(package_name)
  end

  # load last package meta file and just check if sourceaccess flag was used at all, no per user checking atm
  def validate_read_access_of_deleted_package(project, name)
    prj = Project.get_by_name(project)
    if prj.is_a?(Project)
      raise Project::ReadAccessError, project.to_s if prj.disabled_for?('access', nil, nil)
      raise Package::ReadSourceAccessError, "#{target_project_name}/#{target_package_name}" if prj.disabled_for?('sourceaccess', nil, nil)
    end

    begin
      revisions_list = Backend::Api::Sources::Package.revisions(project, name)
    rescue
      raise Package::UnknownObjectError, "#{project}/#{name}"
    end
    data = Xmlhash.parse(revisions_list)
    lastrev = data.elements('revision').last

    query = { deleted: 1 }
    query[:rev] = lastrev.value('srcmd5') if lastrev
    meta = PackageMetaFile.new(project_name: project, package_name: name).content(query)
    raise Package::UnknownObjectError, "#{project}/#{name}" unless meta

    return true if User.current.is_admin?
    if FlagHelper.xml_disabled_for?(Xmlhash.parse(meta), 'sourceaccess')
      raise Package::ReadSourceAccessError, "#{project}/#{name}"
    end
    true
  end

  def validate_visibility_of_deleted_project(project)
    begin
      revisions_list = Backend::Api::Sources::Project.revisions(project)
    rescue
      raise Project::UnknownObjectError, project.to_s
    end
    data = Xmlhash.parse(revisions_list)
    lastrev = data.elements('revision').last
    raise Project::UnknownObjectError, project.to_s unless lastrev

    meta = Backend::Api::Sources::Project.meta(project, revision: lastrev.value('srcmd5'), deleted: 1)
    raise Project::UnknownObjectError unless meta
    return true if User.current.is_admin?
    # FIXME: actually a per user checking would be more accurate here
    raise Project::UnknownObjectError, project.to_s if FlagHelper.xml_disabled_for?(Xmlhash.parse(meta), 'access')
  end
end
