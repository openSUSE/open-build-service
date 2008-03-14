class RequestController < ApplicationController
  validate_action :show => :request

  # GET /request
  alias_method :index, :pass_to_source

  # POST /request?cmd=create
  alias_method :create, :dispatch_command

  # GET /request/:id
  alias_method :show, :pass_to_source

  # POST /request/:id? :cmd :newstate
  def modify
    #TODO: check permissions
    valid_http_methods :post
    path = request.path+'?'+request.query_string
    path << "&user=#{@http_user.login}"
    dispatch_command
  end

  # PUT /request/:id
  def update
    #TODO: check permissions
    path = request.path+'?'+request.query_string
    path << "&user=#{@http_user.login}"
    forward_data path, :method => :put, :data => request.body
  end

  # DELETE /request/:id
  #def destroy
  #  #TODO: check permissions
  #  path = request.path+'?'+request.query_string
  #  path << "&user=#{@http_user.login}"
  #  forward_data path, :method => :delete
  #end

  private
  
  # POST /request?cmd=create
  def create_create
    path = request.path+'?'+request.query_string
    path << "&user=#{@http_user.login}"
    forward_data path, :method => :post, :data => request.body
  end

  def modify_newstate
  end
end
