require 'models/group'

class GroupController < ApplicationController

  def autocomplete
    required_parameters :term
    render :json => Group.list(params[:term])
  end

end
