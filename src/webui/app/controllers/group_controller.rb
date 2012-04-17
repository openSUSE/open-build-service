require 'models/group'

class GroupController < ApplicationController

  include ApplicationHelper

  def autocomplete
    required_parameters :term
    render :json => Group.list(params[:term])
  end

  def index
    @groups = []
    Group.find_cached(:all).each do |entry|
      group = Group.find_cached(entry.value('name'))
      @groups << group if group
    end
  end

  def show
    required_parameters :id
    @group = Group.find_cached(params[:id])
    unless @group
      flash[:error] = "Group '#{params[:id]}' does not exist"
      redirect_back_or_to :action => 'index' and return
    end
  end

end
