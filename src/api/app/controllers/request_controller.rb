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
    req = BsRequest.new(request.body.read)

    msg = req.check_create(@http_user)
    if msg
      render_error :status => 400, :errorcode => 'create_failure',
	:message => msg
      return
    end

    params[:user] = @http_user.login if @http_user
    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    # forward_path is not working here, because we may modify the request.
    # can get cleaned up when we moved this to the client
    response = backend_post( path, req.dump_xml )
    send_data( response, :disposition => "inline" )
    return
  end

  def modify_addreview
     modify_changestate# :cmd => "addreview",
                       # :by_user => params[:by_user], :by_group => params[:by_group]
  end
  def modify_changereviewstate
     modify_changestate # :cmd => "changereviewstate", :newstate => params[:newstate], :comment => params[:comment],
                        #:by_user => params[:by_user], :by_group => params[:by_group]
  end
  def modify_changestate
    req = BsRequest.find params[:id]
    if not @http_user or not @http_user.login
      render_error :status => 403, :errorcode => "post_request_no_permission",
	:message => "Action requires authentifacted user."
      return
    end

    # transform request body into query parameter 'comment'
    # the query parameter is preferred if both are set
    if params[:comment].blank? and request.body
      params[:comment] = request.body.read
    end

    path = request.path + build_query_from_hash(params, [:cmd, :user, :newstate, :by_user, :by_group, :superseded_by, :comment])

    msg = req.check_modify_by_user(@http_user, params)
    if msg
      render_error :status => 400, :errorcode => 'cant_modify',
	:message => msg
    end

    # We have permission to change all requests inside, now execute
    req.each_action do |action|
      if action.data["type"] == "change_devel"
        if params[:newstate] == "accepted"
          target_project = DbProject.find_by_name(action.target.project)
          target_package = target_project.db_packages.find_by_name(action.target.package)
          tpac = Package.new(target_package.to_axml, :project => action.target.project)
          tpac.set_devel :project => action.source.project, :package => action.source.package
          tpac.save
          render_ok
        end
      elsif action.data["type"] == "submit"
        if params[:newstate] == "accepted"
          sourceupdate = nil
          if action.has_element? 'options' and action.options.has_element? 'sourceupdate'
            sourceupdate = action.options.sourceupdate.text
          end
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
            :requestid => params[:id],
            :comment => comment
          }
          cp_params[:orev] = src.rev if src.has_attribute? :rev
          cp_params[:dontupdatesource] = 1 if sourceupdate == "noupdate"

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
          cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :orev, :expand, :comment, :requestid, :dontupdatesource])
          Suse::Backend.post cp_path, nil

          # cleanup source project
          if sourceupdate == "cleanup"
            source_project = DbProject.find_by_name(action.source.project)
            source_package = source_project.db_packages.find_by_name(action.source.package)
            # check for devel package defines
            unless source_package.develpackages.empty?
              msg = "Unable to delete package #{source_package.name}; following packages use this package as devel package: "
              msg += source_package.develpackages.map {|dp| dp.db_project.name+"/"+dp.name}.join(", ")
	      render_error :status => 400, :errorcode => 'develpackage_dependency',
		:message => msg
	    end
            if source_project.db_packages.count == 1
              #find linking repos
              lreps = Array.new
              source_project.repositories.each do |repo|
                repo.linking_repositories.each do |lrep|
                  lreps << lrep
                end
              end
              if lreps.length > 0
                #replace links to this projects with links to the "deleted" project
                del_repo = DbProject.find_by_name("deleted").repositories[0]
                lreps.each do |link_rep|
                  pe = link_rep.path_elements.find(:first, :include => ["link"], :conditions => ["db_project_id = ?", pro.id])
                  pe.link = del_repo
                  pe.save
                  #update backend
                  link_prj = link_rep.db_project
                  logger.info "updating project '#{link_prj.name}'"
                  Suse::Backend.put_source "/source/#{link_prj.name}/_meta", link_prj.to_axml
                end
              end

              # remove source project, if this is the only package
              source_project.destroy
              Suse::Backend.delete "/source/#{action.source.project}"
            else
              # just remove package
              source_package.destroy
              Suse::Backend.delete "/source/#{action.source.project}/#{action.source.package}"
            end
          end
        end
      elsif action.data["type"] == "delete"
        if params[:newstate] == "accepted" # and req.state.name != "accepted" and req.state.name != "declined"
          project = DbProject.find_by_name(action.target.project)
          unless project
	    msg = "Unable to delete project #{action.target.project}; it does not exist."
	    render_error :status => 400, :errorcode => 'not_existing_target',
	      :message => msg
          end
          if not action.target.has_attribute? :package
            project.destroy
            Suse::Backend.delete "/source/#{action.target.project}"
          else
            DbPackage.transaction do
              package = project.db_packages.find_by_name(action.target.package)
              unless package
		msg = "Unable to delete package #{action.target.project}/#{action.target.package}; it does not exist."
		render_error :status => 400, :errorcode => 'not_existing_target',
                  :message => msg
		return
              end
              package.destroy
              Suse::Backend.delete "/source/#{action.target.project}/#{action.target.package}"
            end
          end
          render_ok
        end
      else
	render_error :status => 403, :errorcode => "post_request_no_permission",
          :message => "Failed to execute request state change of request #{req.id} (type #{action.data.attributes['type']})"
        return
      end
    end
  
    forward_data path, :method => :post
  end
end
