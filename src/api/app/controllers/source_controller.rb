require 'json'

include ProductHelper
include MaintenanceHelper
include ValidationHelper

class SourceController < ApplicationController

  validate_action :index => {:method => :get, :response => :directory}
  validate_action :projectlist => {:method => :get, :response => :directory}
  validate_action :packagelist => {:method => :get, :response => :directory}
  validate_action :filelist => {:method => :get, :response => :directory}
  validate_action :project_meta => {:method => :get, :response => :project}
  validate_action :package_meta => {:method => :get, :response => :package}

  validate_action :project_meta => {:method => :put, :request => :project, :response => :status}
  validate_action :package_meta => {:method => :put, :request => :package, :response => :status}

  # /source
  #########
  def index
    # init and validation
    #--------------------
    deleted = params.has_key? :deleted
    admin_user = @http_user.is_admin?
    valid_http_methods :get, :post

    # access checks
    #--------------

    # GET /source
    #------------
    if request.get?
      if deleted
        if admin_user
          pass_to_backend
          return
        else
          render_error :status => 403, :errorcode => 'no_permission_for_deleted',
                       :message => "only admins can see deleted projects"
          return
        end
      else
        projectlist
      end
    # /if request.get?

    # POST /source
    #-------------
    elsif request.post?
      dispatch_command

    # bad request
    #------------
    else
      raise IllegalRequestError.new
    end
  end

  def projectlist
    # list all projects (visible to user)
    dir = DbProject.find(:all, :select => 'name').map {|i| i.name }.sort
    output = String.new
    output << "<?xml version='1.0' encoding='UTF-8'?>\n"
    output << "<directory>\n"
    dir.each do |item|
      output << "  <entry name=\"#{item.to_xs}\"/>\n"
    end
    output << "</directory>\n"
    render :text => output, :content_type => "text/xml"
    return
  end

  # /source/:project
  #-----------------
  def index_project

    # init and validation
    #--------------------
    valid_http_methods :get, :post, :delete
    valid_commands=["undelete", "showlinked", "remove_flag", "set_flag", "createpatchinfo", "createkey", "extendkey", "copy", "createmaintenanceincident", "unlock"]
    raise IllegalRequestError.new "invalid_project_name" unless valid_project_name?(params[:project])
    if params[:cmd]
      raise IllegalRequestError.new "invalid_command" unless valid_commands.include?(params[:cmd])
      command = params[:cmd]
    end
    project_name = params[:project]
    admin_user = @http_user.is_admin?

    # GET /source/:project
    #---------------------
    if request.get?
      if params.has_key? :deleted
        unless DbProject.exists_by_name project_name
          # project is deleted or not accessable
          validate_visibility_of_deleted_project(project_name)
        end
        pass_to_backend
      else
        if DbProject.is_remote_project? project_name
          pass_to_backend
        else
          # for access check
          pro = DbProject.get_by_name project_name
          # we let the backend list the packages after we verified the project is visible
          if params.has_key? :view
            if params["view"] == "issues"
              render :text => pro.render_issues_axml(params), :content_type => 'text/xml'
              return
            end
            pass_to_backend
          else
            @dir = Package.find :all, :project => project_name
            render :text => @dir.dump_xml, :content_type => "text/xml"
          end
        end
      end
      return
    # /request.get?

    # DELETE /source/:project
    #------------------------
    elsif request.delete?
      pro = DbProject.get_by_name project_name

      # checks
      unless @http_user.can_modify_project?(pro)
        logger.debug "No permission to delete project #{project_name}"
        render_error :status => 403, :errorcode => 'delete_project_no_permission',
          :message => "Permission denied (delete project #{project_name})"
        return
      end
      pro.can_be_deleted?

      # find linking repos
      lreps = Array.new
      pro.repositories.each do |repo|
        repo.linking_repositories.each do |lrep|
          lreps << lrep
        end
      end

      if lreps.length > 0
        if params[:force] and not params[:force].empty?
          # replace links to this projects with links to the "deleted" project
          del_repo = DbProject.find_by_name("deleted").repositories[0]
          lreps.each do |link_rep|
            link_rep.path_elements.find(:all).each { |pe| pe.destroy }
            link_rep.path_elements.create(:link => del_repo, :position => 1)
            link_rep.save
            # update backend
            link_rep.db_project.store
          end
        else
          lrepstr = lreps.map{|l| l.db_project.name+'/'+l.name}.join "\n"
          render_error :status => 403, :errorcode => "repo_dependency",
            :message => "Unable to delete project #{project_name}; following repositories depend on this project:\n#{lrepstr}\n"
          return
        end
      end

      # Find open requests with 'pro' as source or target and decline/revoke them.
      # Revoke if source or decline if target went away, pick the first action that matches to decide...
      # Note: As requests are a backend matter, it's pointless to include them into the transaction below
      pro.open_requests_with_project_as_source_or_target.each do |request_id|
        request = BsRequest.find(request_id)
        request.each_action do |action|
          if action.source and action.source.project == pro.name
            request.change_state('revoked', @http_user.login, :comment => "The source project '#{pro.name}' was removed")
            break
          end
          if action.target and action.target.project == pro.name
            request.change_state('declined', @http_user.login, :comment => "The target project '#{pro.name}' was removed")
            break
          end
        end
      end

      # Find open requests which have a review involving this project (or it's packages) and remove those reviews
      # but leave the requests otherwise untouched.
      pro.open_requests_with_by_project_review.each do |request_id|
        BsRequest.find(request_id).remove_reviews(:by_project => pro.name)
      end


      DbProject.transaction do
        logger.info "destroying project object #{pro.name}"
        pro.destroy

        params[:user] = @http_user.login
        path = "/source/#{pro.name}"
        path << build_query_from_hash(params, [:user, :comment])
        Suse::Backend.delete path
        logger.debug "delete request to backend: #{path}"
      end

      render_ok
      return
    # /if request.delete?

    # POST /source/:project
    #----------------------
    elsif request.post?
      params[:user] = @http_user.login

      # command: undelete
      if 'undelete' == command
        unless @http_user.can_create_project?(project_name) and pro.nil?
          render_error :status => 403, :errorcode => "cmd_execution_no_permission",
            :message => "no permission to execute command '#{command}'"
          return
        end
        dispatch_command
        return
      end

      if 'copy' == command
        unless @http_user.can_create_project?(project_name)
          render_error :status => 403, :errorcode => "cmd_execution_no_permission",
            :message => "no permission to execute command '#{command}'"
          return
        end
        if params.has_key?(:makeolder)
          oproject = DbProject.get_by_name(params[:oproject])
          unless @http_user.can_modify_project?(oproject)
            render_error :status => 403, :errorcode => "cmd_execution_no_permission",
              :message => "no permission to execute command '#{command}', requires modification permission in oproject"
            return
          end
        end
        dispatch_command
        return
      end

      pro = DbProject.get_by_name project_name
      # unlock
      if command == "unlock" and @http_user.can_modify_project?(pro, ignoreLock=true)
        dispatch_command
      elsif command == "showlinked" or @http_user.can_modify_project?(pro)
        # command: showlinked, set_flag, remove_flag, ...?
        dispatch_command
      else
        render_error :status => 403, :errorcode => "cmd_execution_no_permission",
          :message => "no permission to execute command '#{command}'"
        return
      end
    # /if request.post?

    # bad request
    #------------
    else
      raise IllegalRequestError.new
    end
  end

  # FIXME: for OBS 3, api of branch and copy calls have target and source in the opossite place
  # /source/:project/:package
  #--------------------------
  def index_package
    # init and validation
    #--------------------
    valid_http_methods :get, :delete, :post
    admin_user = @http_user.is_admin?
    deleted_package = params.has_key? :deleted
    # valid post commands
    valid_commands=['diff', 'branch', 'servicediff', 'linkdiff', 'showlinked', 'copy', 'remove_flag', 'set_flag', 
                    'rebuild', 'undelete', 'wipe', 'runservice', 'commit', 'commitfilelist', 
                    'createSpecFileTemplate', 'deleteuploadrev', 'linktobranch', 'updatepatchinfo',
                    'getprojectservices', 'unlock']
    # list of commands which are allowed even when the project has the package only via a project link
    read_commands = ['branch', 'diff', 'linkdiff', 'servicediff', 'showlinked', 'getprojectservices']
    source_untouched_commands = ['branch', 'diff', 'linkdiff', 'servicediff', 'showlinked', 'rebuild', 'wipe', 'remove_flag', 'set_flag', 'getprojectservices']
    # list of cammands which create the target package
    package_creating_commands = ['branch', 'copy', 'undelete']

    raise IllegalRequestError.new "invalid_project_name" unless valid_project_name?(params[:project])
    if params[:cmd]
      raise IllegalRequestError.new "invalid_command" unless valid_commands.include?(params[:cmd])
      raise IllegalRequestError.new "invalid_command_not_post" unless request.post?
      command = params[:cmd]
    end
    # find out about source and target dependening on command   - FIXME: ugly! sync calls
    if command == 'branch'
      origin_project_name = params[:project]
      target_package_name = origin_package_name = params[:package]
      target_project_name = params[:target_project] if params[:target_project]
      target_package_name = params[:target_package] if params[:target_package]
    else
      target_project_name = params[:project]
      target_package_name = params[:package]
      origin_project_name = params[:oproject] if params[:oproject]
      origin_package_name = params[:opackage] if params[:opackage]
    end
    #
    if origin_package_name and not origin_project_name
        render_error :status => 404, :errorcode => "missing_argument",
        :message => "origin package name is specified, but no origin project"
        return
    end

    # Check for existens/access of origin package when specified
    spkg = nil
    sprj = DbProject.get_by_name origin_project_name                                  if origin_project_name
    if origin_package_name and not [ '_project', '_pattern' ].include? origin_package_name and not (params[:missingok] and command == 'branch')
      spkg = DbPackage.get_by_project_and_name origin_project_name, origin_package_name if origin_package_name and not [ '_project', '_pattern' ].include? origin_package_name
    end
    if spkg
      # use real source in case we followed project link
      params[:oproject] = origin_project_name = spkg.db_project.name
      params[:opackage] = origin_package_name = spkg.name
    end

    tprj = nil
    tpkg = nil
    # The target must exist, except for following cases
    if (request.post? and command == 'undelete') or (request.get? and deleted_package)
      tprj = DbProject.get_by_name(target_project_name)
      if DbPackage.exists_by_project_and_name(target_project_name, target_package_name, follow_project_links=false)
        render_error :status => 404, :errorcode => "package_exists",
          :message => "the package exists already #{tprj.name} #{target_package_name}"
        return
      end
      if command == 'undelete' and request.post?
        tprj = DbProject.get_by_name(target_project_name)
        unless @http_user.can_create_package_in?(tprj)
          render_error :status => 403, :errorcode => "cmd_execution_no_permission",
            :message => "no permission to create package in project #{target_project_name}"
          return
        end
      end
    elsif request.post? and package_creating_commands.include?(command)  # branch/copy
      # The branch command may be used just for simulation
      unless params[:dryrun]
        # we require a target, but are we allowed to modify the existing target ?
        if DbProject.exists_by_name(target_project_name) and DbPackage.exists_by_project_and_name(target_project_name, target_package_name, follow_project_links=false)
          tpkg = DbPackage.get_by_project_and_name(target_project_name, target_package_name, follow_project_links=false)
          unless @http_user.can_modify_package?(tpkg)
            render_error :status => 403, :errorcode => "cmd_execution_no_permission",
              :message => "no permission to execute command '#{command}' for package #{tpkg.name} in project #{tpkg.db_project.name}"
            return
          end
        else
          # branch command may find out target project itself later and checks permission
          exists = DbProject.exists_by_name(target_project_name)
          if command == 'branch' and not exists and target_project_name and not @http_user.can_create_project?(target_project_name)
            render_error :status => 403, :errorcode => "cmd_execution_no_permission",
              :message => "no permission to create project #{target_project_name}"
            return
          end
          if exists 
            tprj = DbProject.get_by_name(target_project_name)
            unless @http_user.can_create_package_in?(tprj)
              render_error :status => 403, :errorcode => "cmd_execution_no_permission",
                :message => "no permission to create package in project #{target_project_name}"
              return
            end
          end
        end
      end
    else
      follow_project_links = false
      follow_project_links = true if request.get? or (source_untouched_commands.include? command)

      if [ '_project', '_pattern' ].include? target_package_name and not request.delete?
        tprj = DbProject.get_by_name target_project_name
      else
        tpkg = DbPackage.get_by_project_and_name(target_project_name, target_package_name, use_source = true, follow_project_links = follow_project_links)
        tprj = tpkg.db_project unless tpkg.nil? # for remote package case
        if request.delete? or (request.post? and not read_commands.include? command)
          # unlock
          if command == "unlock" 
            unless @http_user.can_modify_package?(tpkg, ignoreLock=true)
              render_error :status => 403, :errorcode => "cmd_execution_no_permission",
                :message => "no permission to unlock package #{tpkg.name} in project #{tpkg.db_project.name}"
              return
            end
          elsif not @http_user.can_modify_package?(tpkg)
            render_error :status => 403, :errorcode => "delete_package_no_permission",
              :message => "no permission to delete package #{tpkg.name} in project #{tpkg.db_project.name}"
            return
          end
        end
      end

    end

    # check read access rights when the package does not exist anymore
    if tpkg.nil? and deleted_package
      validate_read_access_of_deleted_package(target_project_name, target_package_name)
    end
    
    # GET /source/:project/:package
    #------------------------------
    if request.get?
      if params["view"] == "issues"
        unless tpkg
          render_error :status => 400, :errorcode => "no_local_package",
            :message => "Issues can only be shown for local packages"
          return
        end
        render :text => tpkg.render_issues_axml(params), :content_type => 'text/xml'
        return
      end

      # exec
      path = request.path
      path << build_query_from_hash(params, [:rev, :linkrev, :emptylink, :expand, :view, :extension, :lastworking, :withlinked, :meta, :deleted, :parse, :arch, :repository])
      pass_to_backend path
      return

    # /request.get?

    # DELETE /source/:project/:package
    #---------------------------------
    elsif request.delete?

      # checks
      if target_package_name == "_project"
        render_error :status => 403, :errorcode => "delete_package_no_permission",
          :message => "_project package can not be deleted."
        return
      end

      # deny deleting if other packages use this as develpackage
      # Shall we offer a --force option here as well ?
      # Shall we ask the other package owner accepting to be a devel package ?
      tpkg.can_be_deleted?

      # Find open requests with 'tpkg' as source or target and decline/revoke them.
      # Revoke if source or decline if target went away, pick the first action that matches to decide...
      # Note: As requests are a backend matter, it's pointless to include them into the transaction below
      tpkg.open_requests_with_package_as_source_or_target.each do |request_id|
        request = BsRequest.find(request_id)
        request.each_action do |action|
          if action.source and action.source.project == tpkg.db_project.name and action.source.package == tpkg.name
            request.change_state('revoked', @http_user.login, :comment => "The source package '#{tpkg.db_project.name} / #{tpkg.name}' was removed")
            break
          end
          if action.target and action.target.project == tpkg.db_project.name and action.target.package == tpkg.name
            request.change_state('declined', @http_user.login, :comment => "The target package '#{tpkg.db_project.name} / #{tpkg.name}' was removed")
            break
          end
        end
      end

      # Find open requests which have a review involving this package and remove those reviews
      # but leave the requests otherwise untouched.
      tpkg.open_requests_with_by_package_review.each do |request_id|
        BsRequest.find(request_id).remove_reviews(:by_project => tpkg.db_project.name, :by_package => tpkg.name)
      end

      # exec
      DbPackage.transaction do
        tpkg.destroy

        params[:user] = @http_user.login
        path = "/source/#{target_project_name}/#{target_package_name}"
        path << build_query_from_hash(params, [:user, :comment])
        Suse::Backend.delete path
    
        if target_package_name == "_product"
          update_product_autopackages params[:project]
        end
      end
      render_ok
      return
    # /request.delete?

    # POST /source/:project/:package
    #-------------------------------
    elsif request.post?

      dispatch_command

    else
      raise IllegalRequestError.new
    end
  end

  # /source/:project/_attribute/:attribute
  # /source/:project/:package/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  #--------------------------------------------------------
  def attribute_meta
    # init and validation
    #--------------------
    valid_http_methods :get, :post, :delete
    params[:user] = @http_user.login if @http_user
    binary=nil
    binary=params[:binary] if params[:binary]
    # valid post commands
    raise IllegalRequestError.new "invalid_project_name" unless valid_project_name?(params[:project])
    if params[:package]
      @attribute_container = DbPackage.get_by_project_and_name(params[:project], params[:package], use_source=false)
    else
      # project
      if DbProject.is_remote_project?(params[:project])
        render_error :status => 400, :errorcode => "remote_project",
          :message => "Attribute access to remote project is not yet supported"
        return
      end
      @attribute_container = DbProject.get_by_name(params[:project])
    end
    # is the attribute type defined at all ?
    if params[:attribute]
      # Valid attribute
      aname = params[:attribute]
      name_parts = aname.split(/:/)
      if name_parts.length != 2
        render_error :status => 400, :errorcode => "invalid_attribute",
          :message => "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
        return
      end
      # existing ?
      at = AttribType.find_by_name(params[:attribute])
      unless at
        render_error :status => 404, :errorcode => "not_existing_attribute",
          :message => "Attribute is not defined in system"
        return
      end
      # only needed for a get request
      params[:namespace] = name_parts[0]
      params[:name] = name_parts[1]
    end


    # GET
    # /source/:project/_attribute/:attribute
    # /source/:project/:package/_attribute/:attribute
    # /source/:project/:package/:binary/_attribute/:attribute
    #--------------------------------------------------------
    if request.get?

      # init
      # checks
      # exec
      render :text => @attribute_container.render_attribute_axml(params), :content_type => 'text/xml'
      return

    # /request.get?

    # DELETE
    # /source/:project/_attribute/:attribute
    # /source/:project/:package/_attribute/:attribute
    # /source/:project/:package/:binary/_attribute/:attribute
    #--------------------------------------------------------
    elsif request.delete?
      # init
      if params[:namespace].blank? or params[:name].blank?
        render_error :status => 400, :errorcode => "missing_attribute",
          :message => "No attribute got specified for delete"
        return
      end
      ac = @attribute_container.find_attribute(params[:namespace], params[:name], binary)

      # checks
      unless ac
          render_error :status => 404, :errorcode => "not_found",
            :message => "Attribute #{aname} does not exist" and return
      end
      if params[:attribute]
        unless @http_user.can_create_attribute_in? @attribute_container, :namespace => name_parts[0], :name => name_parts[1]
          render_error :status => 403, :errorcode => "change_attribute_no_permission",
            :message => "user #{user.login} has no permission to change attribute"
          return
        end
      end

      # exec
      ac.destroy
# FIXME: define how to write it to backend
#      @attribute_container.store
      render_ok

    # /request.delete?

    # POST
    # /source/:project/_attribute/:attribute
    # /source/:project/:package/_attribute/:attribute
    # /source/:project/:package/:binary/_attribute/:attribute
    #--------------------------------------------------------
    elsif request.post?

      # init
      begin
        req = BsRequest.new(request.body.read)
        req.element_name # trigger XML parsing
      rescue ActiveXML::ParseError => e
        render_error :message => "Invalid XML",
          :status => 400, :errorcode => "invalid_xml"
        return
      end

      # checks
    if params[:attribute]
      unless @http_user.can_create_attribute_in? @attribute_container, :namespace => name_parts[0], :name => name_parts[1]
        render_error :status => 403, :errorcode => "change_attribute_no_permission",
          :message => "user #{user.login} has no permission to change attribute"
        return
      end
    else
        req.each_attribute do |attr|
          begin
            can_create = @http_user.can_create_attribute_in? @attribute_container, :namespace => attr.namespace, :name => attr.name
          rescue ActiveRecord::RecordNotFound => e
            render_error :status => 404, :errorcode => "not_found",
              :message => e.message
            return
          rescue ArgumentError => e
            render_error :status => 400, :errorcode => "change_attribute_attribute_error",
              :message => e.message
            return
          end
          unless can_create
            render_error :status => 403, :errorcode => "change_attribute_no_permission",
              :message => "user #{user.login} has no permission to change attribute"
            return
          end
        end
    end

      # exec
      req.each_attribute do |attr|
        begin
          @attribute_container.store_attribute_axml(attr, binary)
        rescue DbProject::SaveError => e
          render_error :status => 403, :errorcode => "save_error", :message => e.message
          return
        rescue DbPackage::SaveError => e
          render_error :status => 403, :errorcode => "save_error", :message => e.message
          return
        end
      end
# FIXME: define how to write it to backend
#      @attribute_container.store
      render_ok

    # /request.post?

    # bad request
    #------------
    else
      raise IllegalRequestError.new
    end
  end

  # /source/:project/_meta
  def project_meta
    # init and validation
    #--------------------
    valid_http_methods :get, :put
    required_parameters :project
    unless valid_project_name?(params[:project])
      render_error :status => 400, :errorcode => "invalid_project_name",
        :message => "invalid project name '#{params[:project]}'"
      return
    end

    project_name = params[:project]
    params[:user] = @http_user.login

    # GET /source/:project/_meta
    #---------------------------
    if request.get?
      if DbProject.find_remote_project project_name
        # project from remote buildservice, get metadata from backend
        pass_to_backend
      else
        # access check
        prj = DbProject.get_by_name(project_name)

        render :text => prj.to_axml(params[:view]), :content_type => 'text/xml'
      end
      return

    # PUT /source/:project/_meta
    #----------------------------
    elsif request.put?
      # init
      # assemble path for backend
      path = request.path
      path += build_query_from_hash(params, [:user, :comment, :rev])
      allowed = false
      request_data = request.raw_post

      # permission check
      p = Project.new(request_data, :name => project_name)
      if( p.name != project_name )
        render_error :status => 400, :errorcode => 'project_name_mismatch',
          :message => "project name in xml data does not match resource path component"
        return
      end
      begin
        prj = DbProject.get_by_name p.name
      rescue DbProject::UnknownObjectError
        prj = nil
      end

      # remote url project must be edited by the admin
      unless @http_user.is_admin?
        if (p.has_element? :remoteurl or p.has_element? :remoteproject)
          render_error :status => 403, :errorcode => "change_project_no_permission",
            :message => "admin rights are required to change remoteurl or remoteproject"
          return
        end
      end

      # parse xml structure of uploaded data
      rdata = ActiveXML::Base.new(request.raw_post.to_s)

      # Need permission
      logger.debug "Checking permission for the put"
      if prj
        # is lock explicit set to disable ? allow the un-freeze of the project in that case ...
        ignoreLock = nil
# do not support unlock via meta data, just via command or request revoke for now
#        ignoreLock = 1 if rdata.has_element?("lock/disable")

        # project exists, change it
        unless @http_user.can_modify_project?(prj, ignoreLock)
          if prj.is_locked?
            logger.debug "no permission to modify LOCKED project #{prj.name}"
            render_error :status => 403, :errorcode => "change_project_no_permission", 
              :message => "The project #{prj.name} is locked"
            return
          end
          logger.debug "user #{user.login} has no permission to modify project #{prj.name}"
          render_error :status => 403, :errorcode => "change_project_no_permission", 
            :message => "no permission to change project"
          return
        end

        # check for raising read access permissions, which can't get ensured atm
        unless prj.disabled_for?('access', nil, nil)
          if p.disabled_for? :access
             render_error :status => 403, :errorcode => "change_project_protection_level",
               :message => "admin rights are required to raise the protection level of a project (it won't be safe anyway)"
             return
          end
        end
        unless prj.disabled_for?('sourceaccess', nil, nil)
          if p.disabled_for? :sourceaccess
             render_error :status => 403, :errorcode => "change_project_protection_level",
               :message => "admin rights are required to raise the protection level of a project (it won't be safe anyway)"
             return
          end
        end
      else
        # project is new
        unless @http_user.can_create_project? project_name
          logger.debug "Not allowed to create new project"
          render_error :status => 403, :errorcode => 'create_project_no_permission',
            :message => "not allowed to create new project '#{project_name}'"
          return
        end
      end

      # the following code checks if the target project of a linked project exists or is not readable by user
      rdata.each_link do |e|
        # permissions check
        tproject_name = e.value("project")
        tprj = DbProject.get_by_name(tproject_name)

        # The read access protection for own and linked project must be the same.
        # ignore this for remote targets
        if tprj.class == DbProject and tprj.disabled_for?('access', nil, nil) and not p.disabled_for?('access')
          render_error :status => 404, :errorcode => "project_read_access_failure" ,
                       :message => "project links work only when both projects have same read access protection level: #{project_name} -> #{tproject_name}"
          return
        end

        logger.debug "project #{project_name} link checked against #{tproject_name} projects permission"
      end

      # Check used repo pathes for existens and read access permissions
      rdata.each("repository/path") do |e|
        # permissions check
        tproject_name = e.value("project")
        tprj = DbProject.get_by_name(tproject_name)
        if tprj.class == DbProject and tprj.disabled_for?('access', nil, nil) # user can access tprj, but backend would refuse to take binaries from there
          render_error :status => 404, :errorcode => "repository_access_failure" ,
                       :message => "The current backend implementation is not using binaries from read access protected projects #{tproject_name}"
          return
        end

        logger.debug "project #{project_name} repository path checked against #{tproject_name} projects permission"
      end

      # find linking repos which get deleted
      removedRepositories = Array.new
      linkingRepositories = Array.new
      if prj
        prj.repositories.each do |repo|
          if !rdata.has_element?("repository[@name='#{repo.name}']") and not repo.remote_project_name
            # collect repositories to remove
            removedRepositories << repo
            linkingRepositories += repo.linking_repositories
          end
        end
      end
      if linkingRepositories.length > 0
        unless params[:force] and not params[:force].empty?
          lrepstr = linkingRepositories.map{|l| l.db_project.name+'/'+l.name}.join "\n"
          render_error :status => 400, :errorcode => "repo_dependency",
            :message => "Unable to delete repository; following repositories depend on this project:\n#{lrepstr}\n"
          return
        end
      end
      if removedRepositories.length > 0
        # do remove
        private_remove_repositories( removedRepositories, (params[:remove_linking_repositories] and not params[:remove_linking_repositories].empty?) )
      end

      # exec
      p.add_person(:userid => @http_user.login) unless prj
      p.save
      render_ok

    # bad request
    #------------
    else
      raise IllegalRequestError.new
    end
  end

  # /source/:project/_config
  def project_config
    valid_http_methods :get, :put

    # check for project
    prj = DbProject.get_by_name(params[:project])

    # assemble path for backend
    params[:user] = @http_user.login

    # GET /source/:project/_config
    if request.get?
      path = request.path
      path += build_query_from_hash(params, [:rev])
      pass_to_backend path
      return
    end

    # assemble path for backend
    path = request.path
    path += build_query_from_hash(params, [:user, :comment])

    # PUT /source/:project/_config
    if request.put?
      unless @http_user.can_modify_project?(prj)
        render_error :status => 403, :errorcode => 'put_project_config_no_permission',
          :message => "No permission to write build configuration for project '#{params[:project]}'"
        return
      end

      pass_to_backend path
      return
    end
    render_error :status => 400, :errorcode => 'illegal_request',
        :message => "Illegal request: #{request.path}"
  end

  # /source/:project/_pubkey
  def project_pubkey
    valid_http_methods :get, :delete

    # check for project
    prj = DbProject.get_by_name(params[:project])

    # assemble path for backend
    params[:user] = @http_user.login if request.delete?
    path = request.path
    path += build_query_from_hash(params, [:user, :comment, :rev])

    # GET /source/:project/_pubkey
    if request.get?
      pass_to_backend path

    # DELETE /source/:project/_pubkey
    elsif request.delete?
      #check for permissions
      upperProject = prj.name.gsub(/:[^:]*$/,"")
      while upperProject != prj.name and not upperProject.blank?
        if DbProject.exists_by_name(upperProject) and @http_user.can_modify_project?(DbProject.get_by_name(upperProject))
          pass_to_backend path
          return
        end
        upperProject = upperProject.gsub(/:[^:]*$/,"")
      end

      if @http_user.is_admin?
        pass_to_backend path
      else
        render_error :status => 403, :errorcode => 'delete_project_pubkey_no_permission',
          :message => "No permission to delete public key for project '#{params[:project]}'. Either maintainer permissions by upper project or admin permissions is needed."
      end
      return
    end
  end

  # /source/:project/:package/_meta
  def package_meta
    valid_http_methods :put, :get
    required_parameters :project, :package
   
    project_name = params[:project]
    package_name = params[:package]

    unless valid_package_name? package_name
      render_error :status => 400, :errorcode => "invalid_package_name",
        :message => "invalid package name '#{package_name}'"
      return
    end

    if request.get?
      # GET /source/:project/:package/_meta
      pack = DbPackage.get_by_project_and_name( project_name, package_name, use_source=false )

      if params.has_key?(:rev) or pack.nil? # and not pro_name 
        # check if this comes from a remote project, also true for _project package
        # or if rev it specified we need to fetch the meta from the backend
        answer = Suse::Backend.get(request.path)
        if answer
          render :text => answer.body.to_s, :content_type => 'text/xml'
        else
          render_error :status => 404, :errorcode => "unknown_package",
            :message => "Unknown package '#{package_name}'"
        end
        return
      end

      render :text => pack.to_axml(params[:view]), :content_type => 'text/xml'

    else
      # PUT /source/:project/:package/_meta

      pkg_xml = Package.new( request.raw_post, :project => project_name, :name => package_name )

      if (pkg_xml.project and pkg_xml.project != project_name)
        render_error :status => 400, :errorcode => 'project_name_mismatch',
          :message => "project name in xml data does not match resource path component"
        return
      end

      if (pkg_xml.name and pkg_xml.name != package_name)
        render_error :status => 400, :errorcode => 'package_name_mismatch',
          :message => "package name in xml data does not match resource path component"
        return
      end

      # check for project
      if DbPackage.exists_by_project_and_name( project_name, package_name, follow_project_links=false )
        # is lock explicit set to disable ? allow the un-freeze of the project in that case ...
        rdata = ActiveXML::Base.new(request.raw_post.to_s)
        ignoreLock = nil
# unlock only via command for now
#        ignoreLock = 1 if rdata.has_element?("lock/disable")

        pkg = DbPackage.get_by_project_and_name( project_name, package_name, use_source=false )
        unless @http_user.can_modify_package?(pkg, ignoreLock)
          render_error :status => 403, :errorcode => "change_package_no_permission",
            :message => "no permission to modify package '#{pkg.db_project.name}'/#{pkg.name}"
          return
        end

        if pkg and not pkg.disabled_for?('sourceaccess', nil, nil)
          if pkg_xml.disabled_for? :sourceaccess
             render_error :status => 403, :errorcode => "change_package_protection_level",
               :message => "admin rights are required to raise the protection level of a package"
             return
          end
        end
      else
        prj = DbProject.get_by_name(project_name)
        unless @http_user.can_create_package_in?(prj)
          render_error :status => 403, :errorcode => "create_package_no_permission",
            :message => "no permission to create a package in project '#{project_name}'"
          return
        end
      end

      begin
        pkg_xml.save
      rescue DbPackage::CycleError => e
        render_error :status => 400, :errorcode => 'devel_cycle', :message => e.message
        return
      end

      render_ok
    end
  end

  # /source/:project/:package/:file
  def file
    valid_http_methods :get, :delete, :put
    project_name = params[:project]
    package_name = params[:package]
    file = params[:file]
    if file.empty?
	return index_package
    end
    path = "/source/#{URI.escape(project_name)}/#{URI.escape(package_name)}/#{URI.escape(file)}"

    #authenticate
    return unless @http_user
    params[:user] = @http_user.login

    if params.has_key?(:deleted) and request.get? 
      if DbProject.exists_by_name(project_name)
        validate_read_access_of_deleted_package(project_name, package_name)
        pass_to_backend
        return
      elsif package_name == "_project"
        validate_visibility_of_deleted_project(project_name)
        pass_to_backend
        return
      end
    end

    prj = DbProject.get_by_name(project_name)
    pack = nil
    allowed = false

    if package_name == "_project" or package_name == "_pattern"
      allowed = permissions.project_change? prj
    else
      if request.get? 
        # a readable package, even on remote instance is enough here
        begin
          pack = DbPackage.get_by_project_and_name(project_name, package_name)
        rescue DbPackage::UnknownObjectError
        end
      else
        # we need a local package here in any case for modifications
        pack = DbPackage.get_by_project_and_name(project_name, package_name)
        allowed = permissions.package_change? pack
      end

      if pack.nil? and request.get?
        # Check if this is a package on a remote OBS instance
        answer = Suse::Backend.get(request.path)
        if answer
          pass_to_backend
          return
        end
      end
    end

    # GET /source/:project/:package/:file
    if request.get?
      if pack # local package
        path = "/source/#{URI.escape(pack.db_project.name)}/#{URI.escape(pack.name)}/#{URI.escape(file)}"
      end
      path += build_query_from_hash(params, [:rev, :meta, :deleted, :limit, :expand])
      pass_to_backend path
      return
    end

    # PUT /source/:project/:package/:file
    if request.put?
      unless allowed
        render_error :status => 403, :errorcode => 'put_file_no_permission',
          :message => "Insufficient permissions to store file in package #{package_name}, project #{project_name}"
        return
      end

      path += build_query_from_hash(params, [:user, :comment, :rev, :linkrev, :keeplink, :meta])

      # file validation where possible
      if params[:file] == "_link"
         validator = Suse::Validator.validate( "link", request.raw_post.to_s)
      elsif params[:file] == "_aggregate"
         validator = Suse::Validator.validate( "aggregate", request.raw_post.to_s)
      elsif params[:package] == "_pattern"
         validator = Suse::Validator.validate( "pattern", request.raw_post.to_s)
      elsif params[:file] == "_service"
         validator = Suse::Validator.validate( "service", request.raw_post.to_s)
      elsif params[:file] == "_patchinfo"
         validator = Suse::Validator.validate( "patchinfo", request.raw_post.to_s)
      end

      # verify link
      if params[:file] == "_link"
        data = ActiveXML::Base.new(request.raw_post.to_s)
        if data
          tproject_name = data.value("project") || project_name
          tpackage_name = data.value("package") || package_name
          if data.has_attribute? 'missingok'
            DbProject.get_by_name(tproject_name) # permission check
            if DbPackage.exists_by_project_and_name(tproject_name, tpackage_name, follow_project_links=true, allow_remote_packages=true)
              render_error :status => 400, :errorcode => 'not_missing',
                :message => "Link contains a missingok statement but link target (#{tproject_name}/#{tpackage_name}) exists."
              return
            end
          else
            tpkg = DbPackage.get_by_project_and_name(tproject_name, tpackage_name)
          end
        end
      end

      # verify patchinfo data
      if params[:file] == "_patchinfo"
        data = ActiveXML::Base.new(request.raw_post.to_s)
        if data and data.packager
          # bugzilla only knows email adresses, so we support automatic conversion
          if data.packager.to_s.include? '@'
            packager = User.find_by_login data.packager
            #FIXME: update _patchinfo file
          end
          packager = User.get_by_login data.packager.to_s unless packager
        end
        # are releasetargets specified ? validate that this project is actually defining them.
        if data and data.releasetarget
          data.each_releasetarget do |rt|
            found = false
            prj.repositories.each do |r|
              r.release_targets.each do |prt|
                if rt.repository
                  found = true if prt.target_repository.db_project.name == rt.project and prt.target_repository.name == rt.repository
                else
                  found = true if prt.target_repository.db_project.name == rt.project
                end
              end
            end

            unless found
              render_error :status => 404, :errorcode => 'releasetarget_not_found',
                :message => "Release target '#{rt.project}/#{rt.repository}' is not defined in this project '#{prj.name}'"
              return
            end
          end
        end
      end

      # _pattern was not a real package in former OBS 2.0 and before, so we need to create the
      # package here implicit to stay api compatible.
      # FIXME3.0: to be revisited
      if package_name == "_pattern" and not DbPackage.exists_by_project_and_name( project_name, package_name, follow_project_links=false )
        pack = DbPackage.new(:name => "_pattern", :title => "Patterns", :description => "Package Patterns")
        prj.db_packages << pack
        pack.save
      end

      pass_to_backend path

      # update package timestamp, kind and issues
      pack.sources_changed unless params[:rev] == 'repository' or [ "_project", "_pattern" ].include? package_name

      update_product_autopackages params[:project] if package_name == "_product"

    # DELETE /source/:project/:package/:file
    elsif request.delete?
      path += build_query_from_hash(params, [:user, :comment, :rev, :linkrev, :keeplink])

      unless allowed
        render_error :status => 403, :errorcode => 'delete_file_no_permission',
          :message => "Insufficient permissions to delete file"
        return
      end

      Suse::Backend.delete path
      unless package_name == "_pattern" or package_name == "_project"
        # _pattern was not a real package in old times
        pack.sources_changed
      end
      if package_name == "_product"
        update_product_autopackages params[:project]
      end
      render_ok
    end
  end

  # /source/:project/:package/_webui_flags
  def package_flags
    valid_http_methods :get
    required_parameters :project, :package

    project_name = params[:project]
    package_name = params[:package]

    unless valid_package_name? package_name
      render_error :status => 400, :errorcode => "invalid_package_name",
        :message => "invalid package name '#{package_name}'"
      return
    end

    pack = DbPackage.get_by_project_and_name( project_name, package_name, use_source=false )
    render :text => pack.expand_flags.to_json, :content_type => 'text/json'
  end

  # /source/:project/_webui_flags
  def project_flags
    valid_http_methods :get
    required_parameters :project

    project_name = params[:project]

    prj = DbProject.get_by_name( project_name )
    render :text => prj.expand_flags.to_json, :content_type => 'text/json'
  end

  # called either directly or from delayed job
  def do_project_copy( tproject, params )
    # copy entire project in the backend
    begin
      path = "/source/#{URI.escape(tproject)}"
      path << build_query_from_hash(params, [:cmd, :user, :comment, :oproject, :withbinaries, :withhistory, :makeolder])
      Suse::Backend.post path, nil
    rescue
      # we need to check results of backend in any case (also timeout error eg)
    end

    # set user if nil, needed for delayed job in DbPackage model
    if User.current == nil
      User.current = User.find_by_login(params[:user])
    end

    # restore all package meta data objects in DB
    backend_pkgs = Collection.find :package, :match => "@project='#{tproject}'"
    backend_pkgs.each_package do |package|
      path = "/source/#{URI.escape(tproject)}/#{package.name}/_meta"
      Package.new(backend_get(path), :project => tproject).save
      DbPackage.find_by_project_and_name(tproject, package.name).sources_changed
    end
  end

  private

  # POST /source?cmd=createmaintenanceincident
  def index_createmaintenanceincident
    # set defaults
    unless params[:attribute]
      params[:attribute] = "OBS:MaintenanceProject"
    end
    noaccess = false
    noaccess = true if params[:noaccess]

    # find maintenance project via attribute
    at = AttribType.find_by_name(params[:attribute])
    unless at
      render_error :status => 403, :errorcode => 'not_found',
        :message => "The given attribute #{params[:attribute]} does not exist"
      return
    end
    prj = DbProject.find_by_attribute_type( at ).first()
    unless @http_user.can_modify_project?(prj)
      render_error :status => 403, :errorcode => "modify_project_no_permission",
        :message => "no permission to modify project '#{prj.name}'"
      return
    end
    
    # check for correct project kind
    unless prj and prj.project_type == "maintenance"
      render_error :status => 400, :errorcode => "incident_has_no_maintenance_project",
        :message => "incident projects shall only create below maintenance projects"
      return
    end

    # create incident project
    incident = create_new_maintenance_incident(prj, nil, nil, noaccess)
    render_ok :data => {:targetproject => incident.db_project.name}
  end

  def private_remove_repositories( repositories, full_remove = false )
    del_repo = DbProject.find_by_name("deleted").repositories[0]

    repositories.each do |repo|
      linking_repos = repo.linking_repositories
      prj = repo.db_project


      if full_remove == true
        # recursive for INDIRECT linked repositories
        unless linking_repos.length < 1
          private_remove_repositories( linking_repos, true )
        end

        # try to remove the repository 
        # but never remove the deleted one
        unless repo == del_repo
          # permission check
          unless @http_user.can_modify_project?(prj)
            render_error :status => 403, :errorcode => 'change_project_no_permission',
              :message => "No permission to remove a repository in project '#{prj.name}'"
            return
          end
        end
      else
        # just modify foreign linking repositories. Always allowed
        linking_repos.each do |lrepo|
          lrepo.path_elements.each do |pe|
            if pe.link == repo
              pe.link = del_repo
              pe.save
            end
          end
          lrepo.db_project.store({:lowprio => true}) # low prio storage
        end
      end

      # remove this repository, but be careful, because we may have done it already.
      if Repository.exists?(repo) and r=prj.repositories.find(repo)
         logger.info "updating project '#{prj.name}'"
         r.destroy
         prj.save
         prj.store({:lowprio => true}) # low prio storage
      end
    end
  end

  # POST /source?cmd=branch (aka osc mbranch)
  def index_branch
    ret = do_branch params
    if ret[:status] == 200
      if ret[:text]
        render ret
      else
        render_ok ret
      end
      return
    end
    render_error ret
  end

  # create a id collection of all projects doing a project link to this one
  # POST /source/<project>?cmd=showlinked
  def index_project_showlinked
    valid_http_methods :post
    project_name = params[:project]

    pro = DbProject.get_by_name(project_name)

    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.collection() do |c|
      pro.find_linking_projects.each do |l|
        p={}
        p[:name] = l.name
        c.project(p)
      end
    end
    render :text => xml, :content_type => "text/xml"
  end

  # unlock a project
  # POST /source/<project>?cmd=unlock
  def index_project_unlock
    valid_http_methods :post
    project_name = params[:project]

    if params[:comment].blank?
      render_error :status => 400, :errorcode => "no_comment",
        :message => "Unlock command requires a comment"
      return
    end

    pro = DbProject.get_by_name(project_name)
    if pro.project_type == "maintenance_incident"
      predicate = "(state/@name='new' or state/@name='review' or state/@name='declined') and action/@type='maintenance_release' and action/source/@project='#{pro.name}'"
      collection = Suse::Backend.post("/search/request?match=#{CGI.escape(predicate)}", nil).body
      c = collection.scan(/request id\="(\d+)"/)
      if c.length > 0
        render_error :status => 403, :errorcode => "open_release_request",
          :message => "Unlock of maintenance incident #{} is not possible, because there is a running release request: #{c.flatten}"
        return
      end
    end

    p = { :comment => params[:comment] }

    f = pro.flags.find_by_flag_and_status("lock", "enable")
    unless f
      render_error :status => 400, :errorcode => "not_locked",
        :message => "project '#{pro.name}' is not locked"
      return
    end
    pro.flags.delete(f)
    pro.store(p)

    # maintenance incidents need special treatment
    if pro.project_type == "maintenance_incident"
      # reopen all release targets
      pro.repositories.each do |repo|
        repo.release_targets.each do |releasetarget|
          releasetarget.trigger = "maintenance"
          releasetarget.save!
        end
      end
      pro.store(p)

      # ensure higher build numbers for re-release
      Suse::Backend.post "/build/#{URI.escape(pro.name)}?cmd=wipe", nil
    end

    render_ok
  end

  # POST /source/<project>?cmd=extendkey
  def index_project_extendkey
    valid_http_methods :post
    project_name = params[:project]

    pro = DbProject.find_by_name project_name

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path
  end

  # POST /source/<project>?cmd=createkey
  def index_project_createkey
    valid_http_methods :post
    project_name = params[:project]

    pro = DbProject.find_by_name project_name

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path
  end

  # POST /source/<project>?cmd=createmaintenanceincident
  def index_project_createmaintenanceincident
    valid_http_methods :post

    noaccess = false
    noaccess = true if params[:noaccess]

    prj = DbProject.get_by_name( params[:project] )
    unless @http_user.can_modify_project?(prj)
      render_error :status => 403, :errorcode => "modify_project_no_permission",
        :message => "no permission to modify project '#{prj.name}'"
      return
    end

    # check for correct project kind
    unless prj and prj.project_type == "maintenance"
      render_error :status => 400, :errorcode => "incident_has_no_maintenance_project",
        :message => "incident projects shall only create below maintenance projects"
      return
    end

    # create incident project
    incident = create_new_maintenance_incident(prj, nil, nil, noaccess)
    render_ok :data => {:targetproject => incident.db_project.name}
  end

  # POST /source/<project>?cmd=undelete
  def index_project_undelete
    valid_http_methods :post
    project_name = params[:project]

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path

    # read meta data from backend to restore database object
    path = request.path + "/_meta"
    Project.new(backend_get(path)).save

    # restore all package meta data objects in DB
    backend_pkgs = Collection.find :package, :match => "@project='#{project_name}'"
    backend_pkgs.each_package do |package|
      path = request.path + "/" + package.name + "/_meta"
      Package.new(backend_get(path), :project => params[:project]).save
    end
  end

  # POST /source/<project>?cmd=copy
  def index_project_copy
    valid_http_methods :post
    project_name = params[:project]
    oproject = params[:oproject]
    repository = params[:repository]

    unless @http_user.is_admin?
      if params[:withbinaries]
        render_error :status => 403, :errorcode => "project_copy_no_permission",
          :message => "no permission to copy project with binaries for non admins"
        return
      end
      if params[:withhistory]
        render_error :status => 403, :errorcode => "project_copy_no_permission",
          :message => "no permission to copy project with source history for non admins"
        return
      end
    end

    # create new project object based on oproject
    unless DbProject.find_by_name project_name
      oprj = DbProject.get_by_name( oproject )
      p = DbProject.new :name => project_name, :title => oprj.title, :description => oprj.description
      p.add_user @http_user, "maintainer"
      oprj.flags.each do |f|
        p.flags.create(:status => f.status, :flag => f.flag, :architecture => f.architecture, :repo => f.repo)
      end
      oprj.repositories.each do |repo|
        r = p.repositories.create :name => repo.name
        r.architectures = repo.architectures
        position = 0
        repo.path_elements.each do |pe|
          position += 1
          r.path_elements << PathElement.new(:link => pe.link, :position => position)
        end
      end
      p.store
    end

    if params.has_key? :nodelay
      do_project_copy(project_name, params)
      render_ok
    else
      # inject as job
      require 'workers/copy_project_job.rb'
      Delayed::Job.enqueue CopyProjectJob.new(project_name, params)
      render_invoked
    end
  end

  # POST /source/<project>?cmd=createpatchinfo
  def index_project_createpatchinfo
    project_name = params[:project]
    # a new_format argument may be given but we don't support the old (and experimental marked) format
    # anymore

    pkg_name = "patchinfo"

    if params[:name]
      pkg_name = params[:name]
    end

    unless valid_package_name? pkg_name
      render_error :status => 400, :errorcode => "invalid_package_name",
        :message => "invalid package name '#{pkg_name}'"
      return
    end

    # create patchinfo package
    pkg = nil
    if DbPackage.exists_by_project_and_name( params[:project], pkg_name )
      pkg = DbPackage.get_by_project_and_name params[:project], pkg_name
      unless params[:force]
        if pkg.db_package_kinds.find_by_kind 'patchinfo'
          render_error :status => 400, :errorcode => "patchinfo_file_exists",
            :message => "createpatchinfo command: the patchinfo #{pkg_name} exists already. Either use force=1 re-create the _patchinfo or use updatepatchinfo for updating."
        else
          render_error :status => 400, :errorcode => "package_already_exists",
            :message => "createpatchinfo command: the package #{pkg_name} exists already, but is  no patchinfo. Please create a new package instead."
        end
        return
      end
    else
      prj = DbProject.get_by_name( params[:project] )
      pkg = DbPackage.new(:name => pkg_name, :title => "Patchinfo", :description => "Collected packages for update")
      prj.db_packages << pkg
      pkg.add_flag("build", "enable", nil, nil)
      pkg.add_flag("publish", "enable", nil, nil) unless prj.flags.find_by_flag_and_status("access", "disable")
      pkg.add_flag("useforbuild", "disable", nil, nil)
      pkg.store
    end

    # create patchinfo XML file
    node = Builder::XmlMarkup.new(:indent=>2)
    attrs = { }
    if pkg.db_project.project_type == "maintenance_incident"
      # this is a maintenance incident project, the sub project name is the maintenance ID
      attrs[:incident] = pkg.db_project.name.gsub(/.*:/, '')
    end
    xml = node.patchinfo(attrs) do |n|
      node.packager    @http_user.login
      node.category    "recommended"
      node.rating      "low"
      node.summary     params[:comment]
      node.description ""
    end
    data = ActiveXML::Base.new(node.target!)
    xml = update_patchinfo( data, pkg )
    p={ :user => @http_user.login, :comment => "generated by createpatchinfo call" }
    patchinfo_path = "/source/#{CGI.escape(pkg.db_project.name)}/#{CGI.escape(pkg.name)}/_patchinfo"
    patchinfo_path << build_query_from_hash(p, [:user, :comment])
    backend_put( patchinfo_path, xml.dump_xml )
    pkg.sources_changed
    render_ok :data => {:targetproject => pkg.db_project.name, :targetpackage => pkg_name}
  end

  # POST /source/<project>/<package>?cmd=updatepatchinfo
  def index_package_updatepatchinfo

    pkg = DbPackage.get_by_project_and_name params[:project], params[:package]

    # get existing file
    patchinfo_path = "/source/#{URI.escape(pkg.db_project.name)}/#{URI.escape(pkg.name)}/_patchinfo"
    data = ActiveXML::Base.new(backend_get(patchinfo_path))
    xml = update_patchinfo( data, pkg, true )

    p={ :user => @http_user.login, :comment => "updated via updatepatchinfo call" }
    patchinfo_path = "/source/#{URI.escape(pkg.db_project.name)}/#{URI.escape(pkg.name)}/_patchinfo"
    patchinfo_path << build_query_from_hash(p, [:user, :comment])
    answer = backend_put( patchinfo_path, xml.dump_xml )
    pkg.sources_changed

    render_ok
  end

  # unlock a package
  # POST /source/<project>/<package>?cmd=unlock
  def index_package_unlock
    valid_http_methods :post

    if params[:comment].blank?
      render_error :status => 400, :errorcode => "no_comment",
        :message => "Unlock command requires a comment"
      return
    end

    p = { :comment => params[:comment] }

    pkg = DbPackage.get_by_project_and_name(params[:project], params[:package])
    f = pkg.flags.find_by_flag_and_status("lock", "enable")
    unless f
      render_error :status => 400, :errorcode => "not_locked",
        :message => "package '#{pkg.db_project.name}/#{pkg.name}' is not locked"
      return
    end
    pkg.flags.delete(f)
    pkg.store(p)

    render_ok
  end

  # Collect all project source services for a package
  # POST /source/<project>/<package>?cmd=getprojectservices
  def index_package_getprojectservices
    valid_http_methods :post

    path = request.path
    path << build_query_from_hash(params, [:cmd])
    pass_to_backend path
  end

  # create a id collection of all packages doing a package source link to this one
  # POST /source/<project>/<package>?cmd=showlinked
  def index_package_showlinked
    valid_http_methods :post
    project_name = params[:project]
    package_name = params[:package]

    pack = DbPackage.find_by_project_and_name( project_name, package_name )

    unless pack
      # package comes from remote instance or is hidden

      # FIXME: return an empty list for now
      # we could request the links on remote instance via that: but we would need to search also localy and merge ...

#      path = "/search/package/id?match=(@linkinfo/package=\"#{CGI.escape(package_name)}\"+and+@linkinfo/project=\"#{CGI.escape(project_name)}\")"
#      answer = Suse::Backend.post path, nil
#      render :text => answer.body, :content_type => 'text/xml'
      render :text => "<collection/>", :content_type => 'text/xml'
      return
    end

    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.collection() do |c|
      pack.find_linking_packages.each do |l|
        p={}
        p[:project] = l.db_project.name
        p[:name] = l.name
        c.package(p)
      end
    end
    render :text => xml, :content_type => "text/xml"
  end

  # POST /source/<project>/<package>?cmd=undelete
  def index_package_undelete
    valid_http_methods :post
    params[:user] = @http_user.login
    project_name = params[:project]
    package_name = params[:package]

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path

    # read meta data from backend to restore database object
    path = request.path + "/_meta"
    Package.new(backend_get(path), :project => params[:project]).save
  end

  # FIXME: obsolete this for 3.0
  # POST /source/<project>/<package>?cmd=createSpecFileTemplate
  def index_package_createSpecFileTemplate
    specfile_path = "#{request.path}/#{params[:package]}.spec"
    begin
      backend_get( specfile_path )
      render_error :status => 400, :errorcode => "spec_file_exists",
        :message => "SPEC file already exists."
      return
    rescue ActiveXML::Transport::NotFoundError
      specfile = File.read "#{RAILS_ROOT}/files/specfiletemplate"
      backend_put( specfile_path, specfile )
    end
    render_ok
  end

  # OBS 3.0: this should be obsoleted, we have /build/ controller for this
  # POST /source/<project>/<package>?cmd=rebuild
  def index_package_rebuild
    project_name = params[:project]
    package_name = params[:package]
    repo_name = params[:repo]
    arch_name = params[:arch]

    # check for sources in this or linked project
    pkg = DbPackage.find_by_project_and_name(project_name, package_name)
    unless pkg
      # check if this is a package on a remote OBS instance
      answer = Suse::Backend.get(request.path)
      unless answer
        render_error :status => 400, :errorcode => 'unknown_package',
          :message => "Unknown package '#{package_name}'"
        return
      end
    end

    path = "/build/#{project_name}?cmd=rebuild&package=#{package_name}"
    if repo_name
      if p.repositories.find_by_name(repo_name).nil?
        render_error :status => 400, :errorcode => 'unknown_repository',
          :message=> "Unknown repository '#{repo_name}'"
        return
      end
      path += "&repository=#{repo_name}"
    end
    if arch_name
      path += "&arch=#{arch_name}"
    end

    backend.direct_http( URI(path), :method => "POST", :data => "" )

    render_ok
  end

  # POST /source/<project>/<package>?cmd=commit
  def index_package_commit
    valid_http_methods :post
    params[:user] = @http_user.login

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment, :rev, :linkrev, :keeplink, :repairlink])
    pass_to_backend path

    pack = DbPackage.find_by_project_and_name( params[:project], params[:package] )
    pack.sources_changed if pack # in case of _project package

    if params[:package] == "_product"
      update_product_autopackages params[:project]
    end
  end

  # POST /source/<project>/<package>?cmd=commitfilelist
  def index_package_commitfilelist
    valid_http_methods :post
    params[:user] = @http_user.login
    project_name = params[:project]
    package_name = params[:package]

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment, :rev, :linkrev, :keeplink, :repairlink])
    answer = pass_to_backend path
    
    pack = DbPackage.find_by_project_and_name( params[:project], params[:package] )
    if pack # in case of _project package
      pack.set_package_kind_from_commit(answer)
      pack.update_timestamp
    end

    if params[:package] == "_product"
      update_product_autopackages params[:project]
    end
  end

  # POST /source/<project>/<package>?cmd=diff
  def index_package_diff
    valid_http_methods :post
    oproject_name = params[:oproject]
    opackage_name = params[:opackage]
 
    path = request.path
    path << build_query_from_hash(params, [:cmd, :rev, :orev, :oproject, :opackage, :expand ,:linkrev, :olinkrev, :unified ,:missingok, :meta, :file, :filelimit, :tarlimit, :view, :withissues, :onlyissues])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=linkdiff
  def index_package_linkdiff
    valid_http_methods :post

    path = request.path
    path << build_query_from_hash(params, [:cmd, :rev, :unified, :linkrev, :file, :filelimit, :tarlimit, :view, :withissues, :onlyissues])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=servicediff
  def index_package_servicediff
    valid_http_methods :post

    path = request.path
    path << build_query_from_hash(params, [:cmd, :rev, :unified, :file, :filelimit, :tarlimit, :view, :withissues, :onlyissues])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=copy
  def index_package_copy
    valid_http_methods :post
    params[:user] = @http_user.login

    sproject = params[:project]
    sproject = params[:oproject] if params[:oproject]
    spackage = params[:package]
    spackage = params[:opackage] if params[:opackage]

    # create target package, if it does not exist
    tpkg = DbPackage.find_by_project_and_name(params[:project], params[:package])
    if tpkg.nil?
      answer = Suse::Backend.get("/source/#{CGI.escape(sproject)}/#{CGI.escape(spackage)}/_meta")
      if answer
        p = Package.new(answer.body, :project => params[:project])
        p.name = params[:package]
        p.save
        tpkg = DbPackage.find_by_project_and_name(params[:project], params[:package])
      else
        render_error :status => 404, :errorcode => 'unknown_package',
          :message => "Unknown package #{spackage} in project #{sproject}"
        return
      end
    end

    # We need to use the project name of package object, since it might come via a project linked project
    path = "/source/#{CGI.escape(tpkg.db_project.name)}/#{CGI.escape(tpkg.name)}"
    path << build_query_from_hash(params, [:cmd, :rev, :user, :comment, :oproject, :opackage, :orev, :expand, :keeplink, :repairlink, :linkrev, :olinkrev, :requestid, :dontupdatesource, :withhistory])
    pass_to_backend path

    tpkg.sources_changed
  end

  # POST /source/<project>/<package>?cmd=runservice
  def index_package_runservice
    valid_http_methods :post
    params[:user] = @http_user.login

    pack = DbPackage.find_by_project_and_name( params[:project], params[:package] )

    path = request.path
    path << build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend path

    pack.sources_changed
  end

  # POST /source/<project>/<package>?cmd=deleteuploadrev
  def index_package_deleteuploadrev
    valid_http_methods :post
    params[:user] = @http_user.login

    path = request.path
    path << build_query_from_hash(params, [:cmd])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=linktobranch
  def index_package_linktobranch
    valid_http_methods :post
    params[:user] = @http_user.login
    prj_name = params[:project]
    pkg_name = params[:package]
    pkg_rev = params[:rev]
    pkg_linkrev = params[:linkrev]

    pkg = DbPackage.get_by_project_and_name prj_name, pkg_name, use_source=true, follow_project_links=false

    #convert link to branch
    rev = ""
    if not pkg_rev.nil? and not pkg_rev.empty?
      rev = "&orev=#{pkg_rev}"
    end
    linkrev = ""
    if not pkg_linkrev.nil? and not pkg_linkrev.empty?
      linkrev = "&linkrev=#{pkg_linkrev}"
    end
    Suse::Backend.post "/source/#{prj_name}/#{pkg_name}?cmd=linktobranch&user=#{CGI.escape(params[:user])}#{rev}#{linkrev}", nil

    pkg.sources_changed
    render_ok
  end

  # POST /source/<project>/<package>?cmd=branch&target_project="optional_project"&target_package="optional_package"&update_project_attribute="alternative_attribute"&comment="message"
  def index_package_branch
    ret = do_branch params
    if ret[:status] == 200
      if ret[:text]
        render ret
      else
        render_ok ret
      end
      return
    end
    render_error ret
  end

  # POST /source/<project>/<package>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def index_package_set_flag
    valid_http_methods :post

    required_parameters :project, :package, :flag, :status

    prj_name = params[:project]
    pkg_name = params[:package]

    pkg = DbPackage.get_by_project_and_name prj_name, pkg_name, use_source=true, follow_project_links=false

    # first remove former flags of the same class
    begin
      pkg.remove_flag(params[:flag], params[:repository], params[:arch])
      pkg.add_flag(params[:flag], params[:status], params[:repository], params[:arch])
    rescue ArgumentError => e
      render_error :status => 400, :errorcode => 'invalid_flag', :message => e.message
      return
    end
    pkg.store
    render_ok
  end

  # POST /source/<project>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def index_project_set_flag
    valid_http_methods :post

    required_parameters :project, :flag, :status
    prj_name = params[:project]
    prj = DbProject.get_by_name prj_name

    begin
      # first remove former flags of the same class
      prj.remove_flag(params[:flag], params[:repository], params[:arch])
      prj.add_flag(params[:flag], params[:status], params[:repository], params[:arch])
    rescue ArgumentError => e
      render_error :status => 400, :errorcode => 'invalid_flag', :message => e.message
      return
    end
      
    # Raising permissions afterwards is not secure. Do not allow this by default.
    unless @http_user.is_admin?
      if params[:flag] == "access" and params[:status] == "enable" and not prj.enabled_for?('access', params[:repository], params[:arch])
        render_error :status => 403, :errorcode => "change_project_protection_level",
        :message => "admin rights are required to raise the protection level of a project"
        return
      end
      if params[:flag] == "sourceaccess" and params[:status] == "enable" and not prj.enabled_for?('sourceaccess', params[:repository], params[:arch])
        render_error :status => 403, :errorcode => "change_project_protection_level",
        :message => "admin rights are required to raise the protection level of a project"
        return
      end
    end

    prj.store
    render_ok
  end

  # POST /source/<project>/<package>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def index_package_remove_flag
    valid_http_methods :post

    required_parameters :project, :package, :flag
    
    pkg = DbPackage.get_by_project_and_name( params[:project], params[:package] )
    
    pkg.remove_flag(params[:flag], params[:repository], params[:arch])
    pkg.store
    render_ok
  end

  # POST /source/<project>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def index_project_remove_flag
    valid_http_methods :post
    required_parameters :project, :flag

    prj_name = params[:project]

    prj = DbProject.get_by_name prj_name

    prj.remove_flag(params[:flag], params[:repository], params[:arch])
    prj.store
    render_ok
  end

end
