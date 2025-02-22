class SourceProjectController < SourceController
  include CheckAndRemoveRepositories

  # GET /source/:project
  def show
    project_name = params[:project]

    if params[:deleted] == '1' && !(Project.find_by_name(project_name) || Project.is_remote_project?(project_name))
      # project is deleted or not accessible
      validate_visibility_of_deleted_project(project_name)
      # We have to pass it to the backend at this point, because the rest
      # of the method expects an existing project
      pass_to_backend
      return
    end

    if Project.is_remote_project?(project_name)
      # not a local project, hand over to backend
      pass_to_backend
      return
    end

    # This implicitly also checks if the user can access the project (for hidden projects).
    # We have to make sure to initialize the project already at this
    # point, even we dont need the object in most cases because of that fact.
    # TODO: Don't implicitly use the finder logic to authorize!
    @project = Project.find_by_name(project_name)
    raise Project::UnknownObjectError, "Project not found: #{project_name}" unless @project

    unless params.key?(:view)
      pass_to_backend
      return
    end

    raise InvalidParameterError, "'#{params[:view]}' is not a valid 'view' parameter value." unless params[:view].in?(%w[verboseproductlist productlist issues info])

    # rubocop:disable Style/RedundantReturn
    case params[:view]
    when 'verboseproductlist'
      @products = Product.all_products(@project, params[:expand])
      render 'source/verboseproductlist', formats: [:xml]
      return
    when 'productlist'
      @products = Product.all_products(@project, params[:expand])
      render 'source/productlist', formats: [:xml]
      return
    when 'issues'
      render_project_issues
    when 'info'
      pass_to_backend
    end
    # rubocop:enable Style/RedundantReturn
  end

  def render_project_issues
    set_issues_defaults
    render partial: 'source/project_issues', formats: [:xml]
  end

  # DELETE /source/:project
  def delete
    project = Project.get_by_name(params[:project])

    # checks
    unless project.is_a?(Project) && User.session.can_modify?(project)
      logger.debug "No permission to delete project #{project}"
      render_error status: 403, errorcode: 'delete_project_no_permission',
                   message: "Permission denied (delete project #{project})"
      return
    end
    project.check_weak_dependencies!
    opts = { no_write_to_backend: true,
             force: params[:force].present?,
             recursive_remove: params[:remove_linking_repositories].present? }
    check_and_remove_repositories!(project.repositories, opts)

    logger.info "destroying project object #{project.name}"
    project.commit_opts = { comment: params[:comment] }
    begin
      project.destroy
    rescue ActiveRecord::RecordNotDestroyed => e
      exception_message = "Destroying Project #{project.name} failed: #{e.record.errors.full_messages.to_sentence}"
      logger.debug exception_message
      raise ActiveRecord::RecordNotDestroyed, exception_message
    end

    render_ok
  end

  # POST /source/:project?cmd
  #-----------------
  def project_command
    # init and validation
    #--------------------
    required_parameters(:cmd)

    valid_commands = %w[undelete showlinked remove_flag set_flag createpatchinfo
                        createkey extendkey copy createmaintenanceincident lock
                        unlock release addchannels modifychannels move freezelink]

    raise IllegalRequest, 'invalid_command' unless valid_commands.include?(params[:cmd])

    command = params[:cmd]
    project_name = params[:project]
    params[:user] = User.session.login

    return dispatch_command(:project_command, command) if command.in?(%w[undelete release copy move])

    @project = Project.get_by_name(project_name)

    raise CmdExecutionNoPermission, "no permission to execute command '#{command}'" unless
      (command == 'unlock' && User.session.can_modify?(@project, true)) ||
      command == 'showlinked' ||
      User.session.can_modify?(@project)

    dispatch_command(:project_command, command)
  end
end
