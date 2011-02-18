require 'models/group'

class GroupController < ApplicationController

  def autocomplete_groups
    required_parameters :q
    @groups = Group.list(params[:q])
    render :text => @groups.join("\n")
  end

end
