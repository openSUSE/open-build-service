class SourceProjectMetaController < SourceController
  validate_action update: { request: :project, response: :status }
  validate_action show: { response: :project }

  # GET /source/:project/_meta
  #---------------------------
  def show
    if Project.find_remote_project params[:project]
      # project from remote buildservice, get metadata from backend
      raise InvalidProjectParameters if params[:view]
      pass_to_backend
    else
      # access check
      prj = Project.get_by_name params[:project]
      render xml: prj.to_axml
    end
  end

  # PUT /source/:project/_meta
  def update
    project_name = params[:project]
    params[:user] = User.current.login

    request_data = Xmlhash.parse(request.raw_post)

    # permission check
    if request_data['name'] != project_name
      raise ProjectNameMismatch, "project name in xml data ('#{request_data['name']}) does not match resource path component ('#{project_name}')"
    end

    begin
      project = Project.get_by_name(request_data['name'])
    rescue Project::UnknownObjectError
      project = nil
    end

    # Need permission
    logger.debug 'Checking permission for the put'
    if project
      # project exists, change it
      unless User.current.can_modify_project?(project)
        if project.is_locked?
          logger.debug "no permission to modify LOCKED project #{project.name}"
          raise ChangeProjectNoPermission, "The project #{project.name} is locked"
        end
        logger.debug "user #{user.login} has no permission to modify project #{project.name}"
        raise ChangeProjectNoPermission, 'no permission to change project'
      end
    else
      # project is new
      unless User.current.can_create_project?(project_name)
        logger.debug 'Not allowed to create new project'
        raise CreateProjectNoPermission, "no permission to create project #{project_name}"
      end
    end

    # projects using remote resources must be edited by the admin
    result = Project.validate_remote_permissions(request_data)
    if result[:error]
      raise ChangeProjectNoPermission, 'admin rights are required to change projects using remote resources'
    end

    result = Project.validate_link_xml_attribute(request_data, project_name)
    raise ProjectReadAccessFailure, result[:error] if result[:error]

    result = Project.validate_maintenance_xml_attribute(request_data)
    raise ModifyProjectNoPermission, result[:error] if result[:error]

    result = Project.validate_repository_xml_attribute(request_data, project_name)
    raise RepositoryAccessFailure, result[:error] if result[:error]

    if project
      remove_repositories = project.get_removed_repositories(request_data)
      opts = { no_write_to_backend: true,
               force:               params[:force].present?,
               recursive_remove:    params[:remove_linking_repositories].present? }
      check_and_remove_repositories!(remove_repositories, opts)
    end

    Project.transaction do
      # exec
      if project
        project.update_from_xml!(request_data)
      else
        project = Project.new(name: project_name)
        project.update_from_xml!(request_data)
        # FIXME3.0: don't modify send data
        project.relationships.build(user: User.current, role: Role.find_by_title!('maintainer'))
      end
      project.store(comment: params[:comment])
    end
    render_ok
  end
end
