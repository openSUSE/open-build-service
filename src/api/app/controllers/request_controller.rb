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

    if req.has_element? 'submit' and req.has_attribute? 'type'
      # old style, convert to new style on the fly
      node = req.submit
      node.data.name = 'action'
      node.data.attributes['type'] = 'submit'
      req.data.attributes['type'] = nil
    end

    req.each_action do |action|
      if action.data.attributes["type"] == "delete"
        #check existence of target
        tprj = DbProject.find_by_name action.target.project
        if tprj
          if action.target.has_attribute? 'package'
            tpkg = tprj.db_packages.find_by_name action.target.package
            unless tpkg
              render_error :status => 404, :errorcode => 'unknown_package',
                :message => "Unknown package  #{action.target.project} / #{action.target.package}"
              return
            end
          end
        else
          unless DbProject.find_remote_project(action.target.project)
            render_error :status => 404, :errorcode => 'unknown_package',
              :message => "Project is on remote instance, delete not possible  #{action.target.project}"
            return
          end
          render_error :status => 404, :errorcode => 'unknown_project',
            :message => "Unknown project #{action.target.project}"
          return
        end
      elsif action.data.attributes["type"] == "submit" or action.data.attributes["type"] == "change_devel"
        #check existence of source
        sprj = DbProject.find_by_name action.source.project
#        unless sprj or DbProject.find_remote_project(action.source.project)
        unless sprj
          render_error :status => 404, :errorcode => 'unknown_project',
            :message => "Unknown source project #{action.source.project}"
          return
        end

        unless action.data.attributes["type"] == "change_devel" and action.source.package.nil?
          # source package is required for submit, but optional for change_devel
          spkg = sprj.db_packages.find_by_name action.source.package
#          unless spkg or DbProject.find_remote_project(action.source.package)
          unless spkg
            render_error :status => 404, :errorcode => 'unknown_package',
              :message => "Unknown source package #{action.source.package} in project #{action.source.project}"
            return
          end
        end

        unless action.data.attributes["type"] == "submit" and action.data.elements['target'].nil?
          # target is required for change_devel, but optional for submit
          tprj = DbProject.find_by_name action.target.project
#          unless sprj or DbProject.find_remote_project(action.source.project)
          unless tprj
            render_error :status => 404, :errorcode => 'unknown_project',
              :message => "Unknown target project #{action.target.project}"
            return
          end
          if action.data.attributes["type"] == "change_devel"
            tpkg = tprj.db_packages.find_by_name action.target.package
            unless tpkg
              render_error :status => 404, :errorcode => 'unknown_project',
                :message => "Unknown target package #{action.target.package}"
              return
            end
          end
        end

        # We only allow submit/change_devel requests from projects where people have write access
        # to avoid that random people can submit versions without talking to the maintainers 
        if spkg
          unless @http_user.can_modify_package? spkg
            render_error :status => 403, :errorcode => "create_request_no_permission",
              :message => "No permission to create request for package '#{spkg.name}' in project '#{sprj.name}'"
            return
          end
        else
          unless @http_user.can_modify_project? sprj
            render_error :status => 403, :errorcode => "create_request_no_permission",
              :message => "No permission to create request based on project '#{sprj.name}'"
            return
          end
        end
      else
        render_error :status => 403, :errorcode => "create_unknown_request",
          :message => "Request type is unknown '#{action.data.attributes["type"]}'"
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

    if req.has_element? 'submit' and req.has_attribute? 'type'
      # old style, convert to new style on the fly
      node = req.submit
      node.data.name = 'action'
      node.data.attributes['type'] = 'submit'
      req.data.attributes['type'] = nil
    end

    path = request.path + build_query_from_hash(params, [:cmd, :user, :newstate, :comment])

    # generic permission check
    permission_granted = false
    if @http_user.is_admin?
      permission_granted = true
    elsif params[:newstate] == "deleted"
      render_error :status => 403, :errorcode => "post_request_no_permission",
               :message => "Deletion of a request is only permitted for administrators. Please revoke the request instead."
      return
    elsif req.state.name == "new" and params[:newstate] == "revoked" and req.creator == @http_user.login
      # allow new -> revoked state change to creators of request
      permission_granted = true
    else
       # do not allow direct switches from accept to decline or vice versa or double actions
       if params[:newstate] == "accepted" or params[:newstate] == "declined"
          if req.state.name == "accepted" or req.state.name == "declined"
             render_error :status => 403, :errorcode => "post_request_no_permission",
               :message => "set state to #{params[:newstate]} from accepted or declined is not allowed."
             return
          end
       end

       # permission check for each request inside
       req.each_action do |action|
         if action.data.attributes["type"] == "submit" or action.data.attributes["type"] == "change_devel"
           source_project = DbProject.find_by_name(action.source.project)
           target_project = DbProject.find_by_name(action.target.project)
           if target_project.nil?
             render_error :status => 403, :errorcode => "post_request_no_permission",
               :message => "Target project is missing in request #{req.id} (type #{action.data.attributes['type']})"
             return
           end
           if action.target.package.nil? and action.data.attributes["type"] == "change_devel"
             render_error :status => 403, :errorcode => "post_request_no_permission",
               :message => "Target package is missing in request #{req.id} (type #{action.data.attributes['type']})"
             return
           end
           if action.target.has_attribute? :package
             target_package = target_project.db_packages.find_by_name(action.target.package)
           else
             target_package = target_project.db_packages.find_by_name(action.source.package)
           end
           if ( target_package and @http_user.can_modify_package? target_package ) or
              ( not target_package and @http_user.can_modify_project? target_project )
              permission_granted = true
           elsif source_project and req.state.name == "new" and params[:newstate] == "revoked" 
              # source project owners should be able to revoke submit requests as well
              source_package = source_project.db_packages.find_by_name(action.source.package)
              if ( source_package and @http_user.can_modify_package? source_package ) or
                 ( not source_package and @http_user.can_modify_project? source_project )
                permission_granted = true
              else
                render_error :status => 403, :errorcode => "post_request_no_permission",
                  :message => "No permission to revoke request #{req.id} (type #{action.data.attributes['type']})"
                return
              end
           else
             render_error :status => 403, :errorcode => "post_request_no_permission",
               :message => "No permission to change state of request #{req.id} to #{params[:newstate]} (type #{action.data.attributes['type']})"
             return
           end
    
         elsif action.data.attributes["type"] == "delete"
           # check permissions for delete
           project = DbProject.find_by_name(action.target.project)
           package = nil
           if action.target.has_attribute? :package
              package = project.db_packages.find_by_name(action.target.package)
           end
           if @http_user.can_modify_project? project or ( package and @http_user.can_modify_package? package )
             permission_granted = true
           else
             render_error :status => 403, :errorcode => "post_request_no_permission",
               :message => "No permission to change state of delete request #{req.id} (type #{action.data.attributes['type']})"
             return
           end
         else
           render_error :status => 403, :errorcode => "post_request_no_permission",
             :message => "Unknown request type #{params[:newstate]} of request #{req.id} (type #{action.data.attributes['type']})"
           return
         end
      end
    end

    # at this point permissions should be granted, but let's double check
    if permission_granted != true
      render_error :status => 403, :errorcode => "post_request_no_permission",
        :message => "No permission to change state of request #{req.id} (INTERNAL ERROR, PLEASE REPORT ! )"
      return
    end

    # We have permission to change all requests inside, now execute
    req.each_action do |action|
      if action.data.attributes["type"] == "change_devel"
        if params[:newstate] == "accepted"
          target_project = DbProject.find_by_name(action.target.project)
          target_package = target_project.db_packages.find_by_name(action.target.package)
          tpac = Package.new(target_package.to_axml, :project => action.target.project)
          tpac.set_devel :project => action.source.project, :package => action.source.package
          tpac.save
          render_ok
        end
        forward_data path, :method => :post
      elsif action.data.attributes["type"] == "submit"
        if params[:newstate] == "accepted"
          src = action.source
          comment = "Copy from #{src.project}/#{src.package} via accept of submit request #{params[:id]}"
          comment += " revision #{src.rev}" if src.has_attribute? :rev
          comment += ".\n"
          comment += "Request was accepted with message:\n#{params[:comment]}\n" if params[:comment]
          cp_params = {
            :cmd => "copy",
            :user => @http_user.login,
            :oproject => src.project,
            :opackage => src.package,
            :comment => comment
          }
          cp_params[:orev] = src.rev if src.has_attribute? :rev

          #create package unless it exists already
          target_project = DbProject.find_by_name(action.target.project)
          if action.target.has_attribute? :package
            target_package = target_project.db_packages.find_by_name(action.target.package)
          else
            target_package = target_project.db_packages.find_by_name(action.source.package)
          end
          unless target_package
            source_project = DbProject.find_by_name(action.source.project)
            source_package = source_project.db_packages.find_by_name(action.source.package)
            target_package = Package.new(source_package.to_axml, :project => action.target.project)
            target_package.name = action.target.package
            target_package.remove_all_persons
            target_package.remove_all_flags
            target_package.remove_devel_project
            target_package.save
          end

          cp_path = "/source/#{action.target.project}/#{action.target.package}"
          cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :orev, :expand, :comment])
          Suse::Backend.post cp_path, nil
        end
        forward_data path, :method => :post
      elsif action.data.attributes["type"] == "delete"
        if params[:newstate] == "accepted" # and req.state.name != "accepted" and req.state.name != "declined"
          project = DbProject.find_by_name(action.target.project)
          if not action.target.has_attribute? :package
            project.destroy
            Suse::Backend.delete "/source/#{action.target.project}"
          else
            DbPackage.transaction do
              package = project.db_packages.find_by_name(action.target.package)
              package.destroy
              Suse::Backend.delete "/source/#{action.target.project}/#{action.target.package}"
            end
          end
          render_ok
        end
        forward_data path, :method => :post
      else
        render_error :status => 403, :errorcode => "post_request_no_permission",
          :message => "Failed to execute request state change of request #{req.id} (type #{action.data.attributes['type']})"
        return
      end
    end
  end
end
