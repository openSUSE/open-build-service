class Webui::RelationshipsController < Webui::BaseController

  before_action :load_object
  before_action :load_target
  before_action :load_role

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

  rescue_from 'ActiveRecord::RecordInvalid' do |exception|
    render_error status: 400, errorcode: 'change_role_failed', message: exception.record.errors.full_messages.join('\n')
  end

  def create
    raise MissingParameterError, "No role is given" unless @role
    @target.add_role(@object, @role)
    render json: { status: 'ok' }
  end

  def remove_user
    # @role can be nil to remove all roles
    @target.remove_role(@object, @role)
    render json: { status: 'ok' }
  end

end
