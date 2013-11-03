module ManageRelationships

  def load_obj
    if login = params[:userid]
      return User.find_by_login!(login)
    elsif title = params[:groupid]
      return ::Group.find_by_title!(title)
    else
      raise MissingParameterError, 'Neither user nor group given'
    end
  end

  def save_person
    begin
      main_object.api_obj.add_role(load_obj, Role.find_by_title!(params[:role]))
    rescue User::NotFound => e
      flash[:error] = e.to_s
      redirect_to add_path(:add_person)
      return
    end
    respond_to do |format|
      format.js { render json: 'ok' }
      format.html do
        flash[:notice] = "Added user #{params[:userid]} with role #{params[:role]}"
        redirect_to users_path
      end
    end
  end

  def save_group
    begin
      main_object.api_obj.add_role(load_obj, Role.find_by_title!(params[:role]))
    rescue ::Group::NotFound => e
      flash[:error] = e.to_s
      redirect_to add_path(:add_group)
      return
    end
    respond_to do |format|
      format.js { render json: 'ok' }
      format.html do
        flash[:notice] = "Added group #{params[:groupid]} with role #{params[:role]}"
        redirect_to users_path
      end
    end
  end

  def remove_role
    begin
      main_object.api_obj.remove_role(load_obj, Role.find_by_title(params[:role]))
    rescue User::NotFound, ::Group::NotFound => e
      flash[:error] = e.summary
    end
    respond_to do |format|
      format.js { render json: 'ok' }
      format.html do
        if params[:userid]
          flash[:notice] = "Removed user #{params[:userid]}"
        else
          flash[:notice] = "Removed group '#{params[:groupid]}'"
        end
        redirect_to users_path
      end
    end
  end
end
