module Webui::RequiresProject

  def render_project_missing
    if params[:project] == User.current.home_project_name
      # checks if the user is registered yet
      flash[:notice] = "Your home project doesn't exist yet. You can create it now by entering some" +
          " descriptive data and press the 'Create Project' button."
      redirect_to :action => :new, :ns => User.current.home_project_name and return
    end
    if request.xhr?
      render :text => "Project not found: #{params[:project]}", :status => 404 and return
    else
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => 'project', :nextstatus => 404 and return
    end
  end

  def require_project
    return unless check_valid_project_name
    @project ||= WebuiProject.find(params[:project])
    unless @project
      return render_project_missing
    end
    # Is this a maintenance master project ?
    @is_maintenance_project = @project.is_maintenance?
  end

  def check_valid_project_name
    required_parameters :project
    unless Project.valid_name? params[:project]
      if request.xhr?
        render :text => 'Not a valid project name', :status => 404 and return false
      else
        flash[:error] = "#{params[:project]} is not a valid project name"
        redirect_to :controller => 'project', :nextstatus => 404 and return false
      end
    end
    return true
  end

end
