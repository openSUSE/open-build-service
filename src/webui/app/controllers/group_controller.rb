class GroupController < ApplicationController

  include ApplicationHelper

  before_filter :overwrite_group, :only => [:edit]

  def autocomplete
    required_parameters :term
    render :json => Group.list(params[:term])
  end

  def show
    required_parameters :group
    @group = Group.find_cached(params[:group])
    unless @group
      flash[:error] = "Group '#{params[:group]}' does not exist"
      redirect_back_or_to :controller => 'main', :action => 'index' and return
    end
  end

  def add
  end

  def edit
    @roles = Role.global_roles
  end

  def save
  end
  
  def overwrite_group
    @displayed_group = @group
    group = find_cached(Group, params['group'] ) if params['group'] && !params['group'].empty?
    @displayed_group = group if group
  end
  private :overwrite_group



end
