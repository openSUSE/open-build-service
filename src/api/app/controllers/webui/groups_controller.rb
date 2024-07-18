class Webui::GroupsController < Webui::WebuiController
  before_action :require_login, except: %i[show autocomplete]
  after_action :verify_authorized, except: %i[show autocomplete]

  def index
    authorize Group.new, :index?
    @groups = Group.includes(:users)
  end

  def show
    @group = Group.includes(:users).find_by_title(params[:title])

    # Group.find_by_title! is self implemented and would raise an 500 error
    return if @group

    flash[:error] = "Group '#{params[:title]}' does not exist"
    redirect_back_or_to({ controller: 'main', action: 'index' })
  end

  def new
    authorize Group.new, :create?
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

  def autocomplete
    groups = Group.where('title LIKE ?', "#{params[:term]}%").pluck(:title) if params[:term]
    render json: groups || []
  end

  private

  def group_params
    params.require(:group).permit(:title, :members)
  end
end
