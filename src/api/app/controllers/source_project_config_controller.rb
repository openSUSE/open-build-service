class SourceProjectConfigController < SourceController
  # GET /source/:project/_config
  def show
    begin
      # 'project' can be a local Project in database or a String that's the name of a remote project, or even raise exceptions
      project = Project.get_by_name(params[:project])
    rescue Project::ReadAccessError, Project::UnknownObjectError => e
      render_error status: 404, message: e.message
      return
    end
    config = project.is_a?(String) ? ProjectConfigFile.new(project_name: project) : project.config

    sliced_params = params.slice(:rev)
    sliced_params.permit!

    return if forward_from_backend(config.full_path(sliced_params.to_h))

    content = config.to_s(sliced_params.to_h)
    unless content
      render_error status: 404, message: config.errors.full_messages.to_sentence
      return
    end
    send_data(content, type: config.response[:type], disposition: 'inline')
  end

  # PUT /source/:project/_config
  def update
    project = Project.get_by_name(params[:project])

    if project.is_a?(String)
      raise PutProjectConfigNoPermission, 'Can\'t write on an remote instance'
    end

    unless User.current.can_modify_project?(project)
      raise PutProjectConfigNoPermission, "No permission to write build configuration for project '#{params[:project]}'"
    end

    params[:user] = User.current.login
    project.config.file = request.body

    sliced_params = params.slice(:user, :comment)
    sliced_params.permit!

    response = project.config.save(sliced_params.to_h)

    unless response
      render_error status: 404, message: project.config.errors.full_messages.to_sentence
      return
    end

    send_data(response.body,
              type: response.fetch('content-type'),
              disposition: 'inline')
  end
end
