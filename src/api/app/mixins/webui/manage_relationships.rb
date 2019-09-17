module Webui::ManageRelationships
  def redirect_after_save
    if switch_to_webui2
      redirect_to(users_path)
    elsif what == :person
      redirect_to(add_path(:add_person))
    else
      redirect_to(add_path(:add_group))
    end
  end

  def save_person_or_group(what)
    authorize main_object, :update?
    begin
      Relationship::AddRole.new(main_object, Role.find_by_title!(params[:role]), check: true, user: params[:userid], group: params[:groupid]).add_role # report error on duplicate
      main_object.store
    rescue NotFoundError,
           Relationship::AddRole::SaveError => e
      flash[:error] = e.to_s
      return redirect_after_save
    end
    respond_to do |format|
      format.js { render json: {}, status: :ok }
      format.html do
        success_str = what == :person ? "user #{params[:userid]}" : "group #{params[:groupid]}"
        flash[:success] = "Added #{success_str} with role #{params[:role]}"
        redirect_to users_path
      end
    end
  end

  def users_path
    url_for(action: :users, project: @project, package: @package)
  end

  def save_person
    save_person_or_group(:person)
  end

  def save_group
    save_person_or_group(:group)
  end

  def load_user_or_group
    login = params[:userid]
    return User.find_by_login!(login) if login
    title = params[:groupid]
    return ::Group.find_by_title!(title) if title
    raise MissingParameterError, 'Neither user nor group given'
  end

  def remove_role
    authorize main_object, :update?
    begin
      main_object.remove_role(load_user_or_group, Role.find_by_title(params[:role]))
      main_object.store
    rescue NotFoundError => e
      flash[:error] = e.to_s
    end
    respond_to do |format|
      format.js { render json: {}, status: :ok }
      format.html do
        if params[:userid]
          flash[:success] = "Removed user #{params[:userid]}"
        else
          flash[:success] = "Removed group '#{params[:groupid]}'"
        end
        redirect_to users_path
      end
    end
  end
end
