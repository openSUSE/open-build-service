class Webui::RelationshipsController < Webui::BaseController

  before_filter :load_object
  before_filter :load_target
  before_filter :load_role

  def load_object
    if login = params[:user]
      @object = User.get_by_login(login)
    elsif title = params[:group]
      @object = Group.get_by_title(title)
    else
      raise MissingParameterError, "Neither user nor group given"
    end
  end

  def load_target
    if params[:package_id].blank?
      @target = Project.get_by_name(params[:project_id])
    else
      @target = Package.find_by_project_and_name(params[:project_id], params[:package_id])
    end
  end

  def load_role
    @role = Role.find_by_title!(params[:role]) if params[:role]
  end

  def create
    raise MissingParameterError, "No role is given" unless @role
    begin
      @target.add_role(@object, @role)
    rescue ActiveRecord::RecordInvalid => e
      render_error status: 400, errorcode: 'change_role_failed', message: e.record.errors.full_messages.join('\n')
      return
    end
    render json: { status: 'ok' }
  end

  def remove_user
    # @role can be nil to remove all roles
    begin
      @target.remove_role(@object, @role)
    rescue ActiveRecord::RecordInvalid => e
      render_error status: 400, errorcode: 'change_role_failed', message: e.record.errors.full_messages.join('\n')
      return
    end
    render json: { status: 'ok' }
  end

end
