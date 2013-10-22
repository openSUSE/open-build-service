class Webui::GroupController < Webui::WebuiController

  include Webui::WebuiHelper

  before_filter :overwrite_group, :only => [:edit]

  def autocomplete
    required_parameters :term
    render :json => WebuiGroup.list(params[:term])
  end

  def tokens
    required_parameters :q
    render json: WebuiGroup.list(params[:q], true)
  end

  def show
    required_parameters :id
    @group = WebuiGroup.find(params[:id])
    unless @group
      flash[:error] = "Group '#{params[:group]}' does not exist"
      redirect_back_or_to :controller => 'main', :action => 'index' and return
    end
  end

  def add
  end

  def edit
    required_parameters :group
    @roles = Role.global_roles
    @members = []
    @displayed_group.person.each do |person |
      user = { 'name' => person.userid }
      @members << user
    end
  end

  def save
    group_opts = { :name => params[:name],
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
    Rails.cache.delete("group_#{group.title}")
    if User.current.is_admin?
      redirect_to controller: :configuration, action: :groups
    else
      redirect_to controller: 'group', action: 'show', id: params[:group]
    end
  end
  
  def overwrite_group
    @displayed_group = @group
    group = WebuiGroup.find(params['group'] ) if params['group'] && !params['group'].empty?
    @displayed_group = group if group
  end
  private :overwrite_group

end
