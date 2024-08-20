module Webui::ManageRelationships
  extend ActiveSupport::Concern

  def save_person_or_group(what)
    authorize main_object, :update?
    begin
      Relationship::AddRole.new(main_object, Role.find_by_title!(params[:role]), check: true, user: params[:userid], group: params[:groupid]).add_role # report error on duplicate
      main_object.store
    rescue NotFoundError,
           Relationship::AddRole::SaveError => e
      flash[:error] = e.to_s
      return redirect_to(custom_users_path)
    end
    respond_to do |format|
      format.js { render json: {}, status: :ok }
      format.html do
        success_str = what == :person ? "user #{params[:userid]}" : "group #{params[:groupid]}"
        flash[:success] = "Added #{success_str} with role #{params[:role]}"
        redirect_to custom_users_path
      end
    end
  end

  def custom_users_path
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
    title = params[:groupid]
    raise MissingParameterError, 'Neither user nor group given' unless login.present? || title.present?

    return User.find_by_login!(login) if login

    ::Group.find_by_title!(title)
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
        flash[:success] = if params[:userid]
                            "Removed user #{params[:userid]}"
                          else
                            "Removed group '#{params[:groupid]}'"
                          end
        redirect_to custom_users_path
      end
    end
  end
end
