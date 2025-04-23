class SourceProjectKeyinfoController < SourceController
  before_action :require_valid_project_name
  before_action :ensure_project_exist, only: [:show]

  # GET /source/:project/_keyinfo
  def show
    pass_to_backend("/source/#{@project.to_param}/_keyinfo?withsslcert=1&donotcreatecert=1")
  end

  def ensure_project_exist
    # 'project' can be a local Project in database or a
    #  String that's the name of a remote project, or even raise exceptions
    @project = Project.get_by_name(params[:project])
  rescue Project::ReadAccessError, Project::UnknownObjectError => e
    render_error status: 404, message: e
  end
end
