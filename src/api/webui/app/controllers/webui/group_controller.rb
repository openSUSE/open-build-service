class Webui::GroupController < Webui::WebuiController

  include Webui::WebuiHelper

  before_filter :overwrite_group, :only => [:edit]

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
    group_opts = {:name => params[:name],
                  :title => params[:name],
                  :members => params[:members]
    }
    begin
      group = WebuiGroup.new(group_opts)
      group.save
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.message
    end
    flash[:success] = "Group '#{group.title}' successfully updated."
    if User.current.is_admin?
      redirect_to controller: :configuration, action: :groups
    else
      redirect_to controller: 'group', action: 'show', id: params[:group]
    end
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
