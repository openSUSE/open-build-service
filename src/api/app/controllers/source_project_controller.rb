class SourceProjectController < SourceController
  # GET /source/:project
  def show
    project_name = params[:project]
    if params.key? :deleted
      unless Project.find_by_name project_name
        # project is deleted or not accessable
        validate_visibility_of_deleted_project(project_name)
      end
      pass_to_backend
      return
    end

    if Project.is_remote_project?(project_name)
      # not a local project, hand over to backend
      pass_to_backend
      return
    end

    @project = Project.find_by_name(project_name)
    raise Project::UnknownObjectError, project_name unless @project
    # we let the backend list the packages after we verified the project is visible
    if params.key? :view
      if params[:view] == 'verboseproductlist'
        @products = Product.all_products(@project, params[:expand])
        render 'source/verboseproductlist'
        return
      elsif params[:view] == 'productlist'
        @products = Product.all_products(@project, params[:expand])
        render 'source/productlist'
        return
      elsif params[:view] == 'issues'
        render_project_issues
      else
        pass_to_backend
      end
      return
    end

    render_project_packages
  end

  def render_project_issues
    set_issues_default
    render partial: 'source/project_issues'
  end

  def render_project_packages
    @packages = params.key?(:expand) ? @project.expand_all_packages : @project.packages.pluck(:name)
    render locals: { expand: params.key?(:expand) }, formats: [:xml]
  end

  # DELETE /source/:project
  def delete
    project = Project.get_by_name(params[:project])

    # checks
    unless project.is_a?(Project) && User.current.can_modify_project?(project)
      logger.debug "No permission to delete project #{project}"
      render_error status: 403, errorcode: 'delete_project_no_permission',
                   message: "Permission denied (delete project #{project})"
      return
    end
    project.check_weak_dependencies!
    opts = { no_write_to_backend: true,
             force:               params[:force].present?,
             recursive_remove:    params[:remove_linking_repositories].present? }
    check_and_remove_repositories!(project.repositories, opts)

    logger.info "destroying project object #{project.name}"
    project.commit_opts = { comment: params[:comment] }
    begin
      project.destroy
    rescue ActiveRecord::RecordNotDestroyed => invalid
      exception_message = "Destroying Project #{project.name} failed: #{invalid.record.errors.full_messages.to_sentence}"
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
    valid_commands = ['undelete', 'showlinked', 'remove_flag', 'set_flag', 'createpatchinfo',
                      'createkey', 'extendkey', 'copy', 'createmaintenanceincident', 'lock',
                      'unlock', 'release', 'addchannels', 'modifychannels', 'move', 'freezelink']

    if params[:cmd] && !params[:cmd].in?(valid_commands)
      raise IllegalRequest, 'invalid_command'
    end

    command = params[:cmd]
    project_name = params[:project]
    params[:user] = User.current.login

    if command.in?(['undelete', 'release', 'copy', 'move'])
      return dispatch_command(:project_command, command)
    end

    @project = Project.get_by_name(project_name)

    # unlock
    if command == 'unlock' && User.current.can_modify_project?(@project, true)
      dispatch_command(:project_command, command)
    elsif command == 'showlinked' || User.current.can_modify_project?(@project)
      # command: showlinked, set_flag, remove_flag, ...?
      dispatch_command(:project_command, command)
    else
      raise CmdExecutionNoPermission, "no permission to execute command '#{command}'"
    end
  end
end
