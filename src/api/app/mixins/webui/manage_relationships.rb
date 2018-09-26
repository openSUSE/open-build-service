module Webui::ManageRelationships
  def load_obj
    login = params[:userid]
    return User.find_by_login!(login) if login
    title = params[:groupid]
    return ::Group.find_by_title!(title) if title
    raise MissingParameterError, 'Neither user nor group given'
  end

  def save_person
    begin
      Relationship.add_user(main_object, load_obj, Role.find_by_title!(params[:role]), nil, true) # report error on duplicate
      main_object.store
    rescue NotFoundError,
           Relationship::SaveError => e
      flash[:error] = e.to_s
      if params[:webui2]
        redirect_to users_path
      else
        redirect_to add_path(:add_person)
      end
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
      Relationship.add_group(main_object, load_obj, Role.find_by_title!(params[:role]), nil, true) # report error on duplicate
      main_object.store
    rescue NotFoundError,
           Relationship::SaveError => e
      flash[:error] = e.to_s
      if params[:webui2]
        redirect_to users_path
      else
        redirect_to add_path(:add_group)
      end
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
      main_object.remove_role(load_obj, Role.find_by_title(params[:role]))
      main_object.store
    rescue NotFoundError => e
      flash[:error] = e.to_s
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
