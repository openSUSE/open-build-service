class SourceProjectConfigController < SourceController
  # GET /source/:project/_config
  append_before_action :ensure_project_exist, only: [:show, :update]

  def show
    config = get_config(@project)

    sliced_params = slice_and_permit(params, [:rev])

    return if forward_from_backend(config.full_path(sliced_params))

    content = config.content(sliced_params)

    unless content
      render_404(config.errors.full_messages.to_sentence)
      return
    end
    send_config(content, config.response[:type])
  end

  # PUT /source/:project/_config
  def update
    ensure_local_project!(@project)
    ensure_access!(User.current, @project)

    params[:user] = User.current.login
    @project.config.file = request.body

    response = @project.config.save(slice_and_permit(params, [:user, :comment]))

    unless response
      render_404(@project.config.errors.full_messages.to_sentence)
      return
    end

    send_config(response.body, response.fetch('content-type'))
  end

  def slice_and_permit(params, needed_params)
    sliced_params = params.slice(*needed_params)
    sliced_params.permit!
    sliced_params.to_h
  end

  def get_config(project)
    project.is_a?(String) ? ProjectConfigFile.new(project_name: project) : project.config
  end

  def send_config(content, content_type)
    send_data(content, type: content_type, disposition: :inline)
  end

  def render_404(message)
    render_error status: 404, message: message
  end

  def ensure_project_exist
    # 'project' can be a local Project in database or a
    #  String that's the name of a remote project, or even raise exceptions
    @project = Project.get_by_name(params[:project])
  rescue Project::ReadAccessError, Project::UnknownObjectError => e
    render_404(e)
  end

  def ensure_access!(user, project)
    unless user.can_modify?(project) # rubocop:disable Style/GuardClause
      raise PutProjectConfigNoPermission,
            "No permission to write build configuration for project '#{params[:project]}'"
    end
  end

  def ensure_local_project!(project)
    if project.is_a?(String) # rubocop:disable Style/GuardClause
      raise PutProjectConfigNoPermission,
            'Can\'t write on an remote instance'
    end
  end
end
