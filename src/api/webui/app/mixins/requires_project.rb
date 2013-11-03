module RequiresProject

  def render_project_missing
    if params[:project] == "home:#{User.current.login}"
      # checks if the user is registered yet
      flash[:notice] = "Your home project doesn't exist yet. You can create it now by entering some" +
          " descriptive data and press the 'Create Project' button."
      redirect_to :action => :new, :ns => 'home:' + User.current.login and return
    end
    unless request.xhr?
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => 'project', :action => 'list_public', :nextstatus => 404 and return
    else
      render :text => "Project not found: #{params[:project]}", :status => 404 and return
    end
  end

  def require_project
    return unless check_valid_project_name
    @project ||= WebuiProject.find(params[:project])
    unless @project
      return render_project_missing
    end
    # Is this a maintenance master project ?
    @is_maintenance_project = @project.project_type == 'maintenance'
  end

  def check_valid_project_name
    required_parameters :project
    unless Project.valid_name? params[:project]
      unless request.xhr?
        flash[:error] = "#{params[:project]} is not a valid project name"
        redirect_to :controller => 'project', :action => 'list_public', :nextstatus => 404 and return false
      else
        render :text => 'Not a valid project name', :status => 404 and return false
      end
    end
    return true
  end

end