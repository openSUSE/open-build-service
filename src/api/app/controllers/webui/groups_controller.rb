class Webui::GroupsController < Webui::WebuiController
  include Webui::NotificationsHandler

  before_action :require_login, except: :show
  before_action :require_admin, only: %i[index create new]
  before_action :set_group, only: %i[show edit update]
  before_action :set_members, only: :create
  after_action :verify_authorized, except: %i[index show new autocomplete]

  def index
    @groups = Group.includes(:users).order(:title)
  end

  def show
    @current_notification = handle_notification
  end

  def new; end

  def edit
    authorize @group
  end

  def create
    group = Group.new(group_params.slice(:email, :title).compact)
    authorize group

    group.users = @members

    if group.save
      redirect_to groups_path, success: "Group '#{group}' successfully created."
    else
      redirect_back_or_to root_path, error: "Group can't be saved: #{group.errors.full_messages.to_sentence}"
    end
  end

  def update
    authorize @group

    if @group.update(email: group_params[:email])
      redirect_to groups_path, success: 'Group email successfully updated'
    else
      flash[:error] = "Couldn't update group: #{@group.errors.full_messages.to_sentence}"
    end
  end

  def autocomplete
    groups = Group.where('title LIKE ?', "#{params[:term]}%").order(:title).pluck(:title) if params[:term]
    render json: groups || []
  end

  private

  def set_group
    @group = Group.includes(:users).find_by(title: params[:title])
    return if @group

    redirect_back_or_to root_path, error: "Group '#{params[:title]}' not found"
  end

  def set_members
    @members = []

    group_params[:members].split(',').uniq.each do |login|
      user = User.active.find_by(login: login)
      @members << user if user
      next if user

      redirect_back_or_to root_path, error: "Group can't be saved: User #{login} not found"
      return
    end
  end

  def group_params
    params.expect(group: %i[title email members])
  end
end
