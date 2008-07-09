class RequestController < ApplicationController
  #TODO: request schema validation

  # GET /request
  alias_method :index, :pass_to_source

  # POST /request?cmd=create
  alias_method :create, :dispatch_command

  # GET /request/:id
  alias_method :show, :pass_to_source

  # POST /request/:id? :cmd :newstate
  alias_method :modify, :dispatch_command

  # PUT /request/:id
  def update
    params[:user] = @http_user.login if @http_user
    
    #TODO: allow PUT for non-admins
    unless @http_user.is_admin?
      render_error :status => 403, :errorcode => 'put_request_no_permission',
        :message => "PUT on requests currently requires admin privileges"
    end

    path = request.path
    path << build_query_from_hash(params, [:user])
    forward_data path, :method => :put, :data => request.body
  end

  # DELETE /request/:id
  #def destroy
  #TODO: implement HTTP DELETE as state change to 'deleted'
  #end

  private
  
  # POST /request?cmd=create
  def create_create
    if request.body.kind_of? StringIO
      req = BsRequest.new(request.body.read)
    else
      req = BsRequest.new(request.body)
    end

    if req.type == "submit"
      #check existence of source/target
      tprj = DbProject.find_by_name req.submit.target.project
      unless tprj
        render_error :status => 404, :errorcode => 'unknown_project',
          :message => "Unknown project #{req.submit.target.project}"
        return
      end

      tpkg = tprj.db_packages.find_by_name req.submit.target.package
      unless tpkg
        render_error :status => 404, :errorcode => 'unknown_package',
          :message => "Unknown package #{req.submit.target.package}"
        return
      end

      sprj = DbProject.find_by_name req.submit.source.project
      unless sprj
        render_error :status => 404, :errorcode => 'unknown_project',
          :message => "Unknown project #{req.submit.source.project}"
        return
      end

      spkg = sprj.db_packages.find_by_name req.submit.source.package
      unless spkg
        render_error :status => 404, :errorcode => 'unknown_package',
          :message => "Unknown package #{req.submit.source.package}"
        return
      end
    end

    #check permissions
    unless @http_user.can_modify_package? spkg
      render_error :status => 403, :errorcode => "create_request_no_permission",
        :message => "No permission to create submit request for package '#{spkg.name}' in project '#{sprj.name}'"
      return
    end

    params[:user] = @http_user.login if @http_user
    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])

    forward_data path, :method => :post, :data => req.dump_xml
  end

  def modify_changestate
    req = BsRequest.find params[:id]
    params[:user] = @http_user.login if @http_user

    path = request.path + build_query_from_hash(params, [:cmd, :user, :newstate])
    if req.type == "submit"
      prj = DbProject.find_by_name(req.submit.target.project)
      if @http_user.can_modify_project? prj
        if params[:newstate] == "accepted"
          src = req.submit.source
          cp_params = {
            :cmd => "copy",
            :user => @http_user.login,
            :oproject => src.project,
            :opackage => src.package
          }
          cp_params[:orev] = src.rev if src.has_attribute? :rev
          
          cp_path = "/source/#{req.submit.target.project}/#{req.submit.target.package}"
          cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :orev, :expand])
          Suse::Backend.post cp_path, nil
        end
        forward_data path, :method => :post
      else
        render_error :status => 403, :errorcode => "post_request_no_permission",
          :message => "No permission to change state of request #{req.id} (type #{req.type})"
        return
      end
    else
      #request != submit
      if @http_user.is_admin?
        forward_data path, :method => :post
      else
        render_error :status => 403, :errorcode => "post_request_no_permission",
          :message => "No permission to change state of request #{req.id} (type #{req.type})"
        return
      end
    end
    
  end
end
