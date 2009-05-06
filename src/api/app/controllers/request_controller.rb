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

    if req.type == "delete"
      #check existence of target
      # WORKAROUND: use each_delete[0] instead of delete to workaround usage of delete function
      delete_obj = req.each_delete[0]
      tprj = DbProject.find_by_name delete_obj.project
      unless tprj
        render_error :status => 404, :errorcode => 'unknown_project',
          :message => "Unknown project #{delete_obj.project}"
        return
      end
      tpkg = tprj.db_packages.find_by_name delete_obj.package
      unless tpkg or DbProject.find_remote_package(delete_obj.project, delete_obj.package)
        render_error :status => 404, :errorcode => 'unknown_package',
          :message => "Unknown package  #{delete_obj.project} / #{delete_obj.package}"
        return
      end
    end

    if req.type == "submit"
      #check existence of source
      sprj = DbProject.find_by_name req.submit.source.project
#      unless sprj or DbProject.find_remote_project(req.submit.source.project)
      unless sprj
        render_error :status => 404, :errorcode => 'unknown_project',
          :message => "Unknown project #{req.submit.source.project}"
        return
      end

      spkg = sprj.db_packages.find_by_name req.submit.source.package
#      unless spkg or DbProject.find_remote_project(req.submit.source.package)
      unless spkg
        render_error :status => 404, :errorcode => 'unknown_package',
          :message => "Unknown package #{req.submit.source.package}"
        return
      end

      #check permissions
      unless @http_user.can_modify_package? spkg
        #ADRIAN: what is the reason that we do not allow requests from random projects ?
        render_error :status => 403, :errorcode => "create_request_no_permission",
          :message => "No permission to create submit request for package '#{spkg.name}' in project '#{sprj.name}'"
        return
      end
    end

    params[:user] = @http_user.login if @http_user
    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    forward_data path, :method => :post, :data => req.dump_xml
  end

  def modify_changestate
    req = BsRequest.find params[:id]
    params[:user] = @http_user.login if @http_user

    # transform request body into query parameter 'comment'
    # the query parameter is preferred if both are set
    if params[:comment].blank? and not request.body.eof?
      params[:comment] = request.body.read
    end

    # generic permission check
    permission_granted = false
    if @http_user.is_admin?
      permission_granted = true
    elsif req.state.name == "new" and params[:newstate] == "revoked"
      # allow new -> revoked state change to creators of request
      for h in req.each_history
        if h.name == "new" and h.who == @http_user.login
          permission_granted = true
        end
      end
    end

    path = request.path + build_query_from_hash(params, [:cmd, :user, :newstate, :comment])
    if req.type == "submit"

      source_project = DbProject.find_by_name(req.submit.source.project)
      source_package = DbProject.find_by_name(req.submit.source.package)
      target_project = DbProject.find_by_name(req.submit.target.project)
      if req.submit.target.has_attribute? :package
        target_package = target_project.db_packages.find_by_name(req.submit.target.package)
      else
        target_package = target_project.db_packages.find_by_name(req.submit.source.package)
      end
      if ( target_package and @http_user.can_modify_package? target_package ) or
         ( not target_package and @http_user.can_modify_project? target_project )
         permission_granted = true
      elsif req.state.name == "new" and params[:newstate] == "revoked" and @http_user.can_modify_package?(source_package)
        permission_granted = true
      end

      if permission_granted == true
        if params[:newstate] == "accepted"
          src = req.submit.source
          cp_params = {
            :cmd => "copy",
            :user => @http_user.login,
            :oproject => src.project,
            :opackage => src.package,
            :comment => "Copy from #{src.project}/#{src.package} via accept of submit request #{params[:id]}\nRequest was accepted with message:\n#{params[:comment]}"
          }
          cp_params[:orev] = src.rev if src.has_attribute? :rev

          #create package unless it exists already
          unless target_prj.db_packages.find_by_name(req.submit.target.package)
            source_pkg = Package.find src.package.to_s, :project => src.project.to_s
            target_pkg = Package.new(source_pkg.dump_xml, :project => req.submit.target.project)
            target_pkg.name = req.submit.target.package
            target_pkg.remove_all_persons
            target_pkg.remove_all_flags
            target_pkg.add_person :userid => params[:user]
            target_pkg.save
          end

          cp_path = "/source/#{req.submit.target.project}/#{req.submit.target.package}"
          cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :orev, :expand, :comment])
          Suse::Backend.post cp_path, nil
        end
        forward_data path, :method => :post
      else
        render_error :status => 403, :errorcode => "post_request_no_permission",
          :message => "No permission to change state of request #{req.id} (type #{req.type})"
        return
      end
    elsif req.type == "delete"
      # WORKAROUND: use each_delete[0] instead of delete to workaround usage of delete function
      delete_obj = req.each_delete[0]
      # check permissions for delete
      project = DbProject.find_by_name(delete_obj.project)
      package = project.db_packages.find_by_name(delete_obj.package)
      if @http_user.can_modify_project? project or @http_user.can_modify_package? package
        permission_granted = true
      end

      if permission_granted == true
        if params[:newstate] == "accepted" and req.state.name != "accepted" and req.state.name != "declined"
          if not delete_obj.has_attribute? :package
            project.destroy
            Suse::Backend.delete "/source/#{delete_obj.project}"
          else
            DbPackage.transaction do
              package.destroy
              Suse::Backend.delete "/source/#{delete_obj.project}/#{delete_obj.package}"
            end
          end
          render_ok
        end
        forward_data path, :method => :post
      else
        render_error :status => 403, :errorcode => "delete_package_no_permission",
          :message => "no permission to delete package #{delete_obj.package} in project #{delete_obj.project}"
        return
      end
    elsif @http_user.is_admin?
      #request != submit
      forward_data path, :method => :post
    else
      render_error :status => 403, :errorcode => "post_request_no_permission",
        :message => "No permission to change state of request #{req.id} (type #{req.type})"
      return
    end
  end
end
