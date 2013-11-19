class Webui::GroupController < Webui::WebuiController

  include Webui::WebuiHelper

  before_filter :overwrite_group, only: [:edit]
  before_filter :require_admin, only: [:save]

  def autocomplete
    required_parameters :term
    render json: list_groups(params[:term])
  end

  def tokens
    required_parameters :q
    render json: list_groups(params[:q], true)
  end

  def show
    required_parameters :id
    @group = Group.find_by_title(params[:id])
    unless @group
      flash[:error] = "Group '#{params[:id]}' does not exist"
      redirect_back_or_to :controller => 'main', :action => 'index'
    end
  end

  def add
  end

  def edit
    required_parameters :group
    @roles = Role.global_roles
    @members = []
    @displayed_group.users.each do |person|
      user = {'name' => person.login }
      @members << user
    end
  end

  def save
    group = Group.where(title: params[:name]).first_or_create
    Group.transaction do
      group.users.delete_all
      params[:members].split(',').each do |m|
        group.users << User.find_by_login!(m)
      end
      group.save!
    end
    flash[:success] = "Group '#{group.title}' successfully updated."
    redirect_to controller: :configuration, action: :groups
  end

  def overwrite_group
    @displayed_group = @group
    group = Group.find_by_title(params['group']) if params['group'].present?
    @displayed_group = group if group
  end

  private :overwrite_group

  protected

  def list_groups(prefix=nil, hash=nil)
    names = []
    groups = Group.arel_table
    Group.where(groups[:title].matches("#{prefix}%")).pluck(:title).each do |group|
      if hash
        names << {'name' => group}
      else
        names << group
      end
    end
    names
  end

end
