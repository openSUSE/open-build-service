class SourceProjectConfigController < SourceController
  before_action :require_valid_project_name
  before_action :ensure_project_exist, only: %i[show update]

  # GET /source/:project/_config
  def show
    config = get_config(@project)

    sliced_params = slice_and_permit(params, [:rev])

    return if forward_from_backend(config.full_path(sliced_params))

    content = config.content(sliced_params)

    unless content
      render_error status: 404, message: config.errors.full_messages.to_sentence
      return
    end
    send_config(content, config.response[:type])
  end

  # PUT /source/:project/_config
  def update
    # necessary to pass the policy_class here
    # if its remote prj is a string
    authorize @project, :update?, policy_class: ProjectPolicy

    params[:user] = User.session.login
    @project.config.file = request.body

    response = @project.config.save(slice_and_permit(params, %i[user comment]))

    unless response
      render_error status: 404, message: @project.config.errors.full_messages.to_sentence
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

  def ensure_project_exist
    # 'project' can be a local Project in database or a
    #  String that's the name of a remote project, or even raise exceptions
    @project = Project.get_by_name(params[:project])
  rescue Project::ReadAccessError, Project::UnknownObjectError => e
    render_error status: 404, message: e
  end
end
