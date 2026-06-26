class Webui::GroupsController < Webui::WebuiController
  include Webui::NotificationsHandler

  before_action :require_login, except: %i[show autocomplete]
  after_action :verify_authorized, except: %i[show autocomplete edit update]

  def index
    authorize Group.new, :index?
    @groups = Group.includes(:users).order(:title)
  end

  def show
    @group = Group.includes(:users).find_by_title(params[:title])
    unless @group
      flash[:error] = "Group '#{params[:title]}' does not exist"
      redirect_back_or_to({ controller: 'main', action: 'index' })
      return
    end

    @current_notification = handle_notification
  end

  def new
    authorize Group.new, :create?
  end

  def edit
    @group = Group.find_by(title: params[:title])

    if @group
      authorize(@group, :update?)
    else
      flash[:error] = "The group doesn't exist"
      redirect_to(groups_path)
    end
  end

  def create
    group = Group.new(title: group_params[:title])
    authorize group, :create?

    group.transaction do
      group.save!
      raise ActiveRecord::RecordInvalid unless group.replace_members(group_params[:members])
    end

    flash[:success] = "Group '#{group}' successfully created."
    redirect_to controller: :groups, action: :index
  rescue ActiveRecord::RecordInvalid
    redirect_back_or_to root_path, error: "Group can't be saved: #{group.errors.full_messages.to_sentence}"
  end

  def update
    @group = Group.find_by(title: params[:title])

    unless @group
      flash[:error] = "The group doesn't exist"
      redirect_to(groups_path) && return
    end

    authorize @group, :update?

    if @group.update(email: group_params[:email])
      flash[:success] = 'Group email successfully updated'
      redirect_to groups_path
    else
      flash[:error] = "Couldn't update group: #{@group.errors.full_messages.to_sentence}"
    end
  end

  def autocomplete
    groups = Group.where('title LIKE ?', "#{params[:term]}%").order(:title).pluck(:title) if params[:term]
    render json: groups || []
  end

  private

  def group_params
    params.require(:group).permit(:title, :email, :members)
  end
end
