class SourceProjectMetaController < SourceController
  include CheckAndRemoveRepositories

  validate_action update: { request: :project, response: :status }
  validate_action show: { response: :project }

  before_action :require_valid_project_name
  before_action :set_request_data, only: [:update]
  before_action :require_project_name, only: [:update]

  before_action only: [:update] do
    validate_xml_content @request_data['name'],
                         @project_name,
                         'project_name_mismatch',
                         'project name in xml data does not match resource path component'
  end

  # GET /source/:project/_meta
  #---------------------------
  def show
    if Project.find_remote_project(params[:project])
      # project from remote buildservice, get metadata from backend
      raise InvalidProjectParameters if params[:view]

      pass_to_backend
    else
      # access check
      prj = Project.get_by_name(params[:project])
      render xml: prj.to_axml
    end
  end

  # PUT /source/:project/_meta
  def update
    params[:user] = User.session.login
    begin
      project = Project.get_by_name(@request_data['name'])
    rescue Project::UnknownObjectError
      project = nil
    end

    # Need permission
    logger.debug 'Checking permission for the put'
    if project.is_a?(Project)
      # project exists, change it
      unless User.session.can_modify?(project)
        if project.locked?
          logger.debug "no permission to modify LOCKED project #{project.name}"
          raise ChangeProjectNoPermission, "The project #{project.name} is locked"
        end
        logger.debug "user #{user.login} has no permission to modify project #{project.name}"
        raise ChangeProjectNoPermission, 'no permission to change project'
      end
    else
      # project is new
      unless User.session.can_create_project?(@project_name)
        logger.debug 'Not allowed to create new project'
        raise CreateProjectNoPermission, "no permission to create project #{@project_name}"
      end
    end

    # projects using remote resources must be edited by the admin
    ensure_access_to_edit_remote_project(@request_data)

    ensure_xml_attributes_are_valid(@request_data, @project_name)

    remove_repositories!(project, @request_data, params) if project.is_a?(Project)

    Project.transaction do
      # exec
      if project.is_a?(Project)
        project.update_from_xml!(@request_data)
      else
        project = Project.new(name: @project_name)
        project.update_from_xml!(@request_data)
        unless CONFIG['prevent_adding_maintainer_in_project_creation_with_api'].in?([:on, ':on', 'on', 'true', true])
          # FIXME3.0: don't modify send data
          maintainer_role = Role.find_by_title!('maintainer')
          project.relationships.find_or_initialize_by(user: User.session, role: maintainer_role) unless project.relationships.any? do |relationship|
                                                                                                          relationship.user == User.session && relationship.role == maintainer_role
                                                                                                        end
        end
      end
      project.store(comment: params[:comment])
    end
    render_ok
  end

  def remove_repositories!(project, request_data, params)
    remove_repositories = project.get_removed_repositories(request_data)
    opts = { no_write_to_backend: true,
             force: params[:force].present?,
             recursive_remove: params[:remove_linking_repositories].present? }
    check_and_remove_repositories!(remove_repositories, opts)
  end

  def ensure_access_to_edit_remote_project(request_data)
    result = Project.validate_remote_permissions(request_data)
    error_message = 'admin rights are required to change projects using remote resources'
    raise ChangeProjectNoPermission, error_message if result[:error]
  end

  def ensure_xml_attributes_are_valid(request_data, project_name)
    result = Project.validate_link_xml_attribute(request_data, project_name)
    raise ProjectReadAccessFailure, result[:error] if result[:error]

    result = Project.validate_maintenance_xml_attribute(request_data)
    raise ModifyProjectNoPermission, result[:error] if result[:error]

    result = Project.validate_repository_xml_attribute(request_data, project_name)
    raise RepositoryAccessFailure, result[:error] if result[:error]
  end

  private

  def require_project_name
    required_parameters :project
    @project_name = params[:project]
  end
end
