require "rexml/document"

include ProductHelper
include MaintenanceHelper

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
    dir = Project.find :all
    render :text => dir.dump_xml, :content_type => "text/xml"
    return
  end

  # /source/:project
  #-----------------
  def index_project

    # init and validation
    #--------------------
    valid_http_methods :get, :post, :delete, :put
    valid_commands=["undelete", "showlinked", "remove_flag", "set_flag", "createpatchinfo", "createkey", "extendkey", "copy"]
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
        # FIXME2.2: this would grants access to hidden projects
        pass_to_backend
      else
        if DbProject.is_remote_project? project_name
          pass_to_backend
        else
          # for access check
          pro = DbProject.get_by_name project_name
          @dir = Package.find :all, :project => project_name
          render :text => @dir.dump_xml, :content_type => "text/xml"
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
      # deny deleting if other packages use this as develproject
      unless pro.develpackages.empty?
        msg = "Unable to delete project #{pro.name}; following packages use this project as develproject: "
        msg += pro.develpackages.map {|pkg| pkg.db_project.name+"/"+pkg.name}.join(", ")
        render_error :status => 400, :errorcode => 'develproject_dependency',
          :message => msg
        return
      end
      # check all packages, if any get refered as develpackage
      pro.db_packages.each do |pkg|
        msg = ""
        pkg.develpackages do |dpkg|
          if pro != dpkg.db_project
            msg += dpkg.db_project.name + "/" + dkg.name + ", "
          end
        end
        unless msg == ""
          render_error :status => 400, :errorcode => 'develpackage_dependency',
            :message => "Unable to delete package #{pkg.name}; following packages use this package as devel package: #{msg}"
          return
        end
      end

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

      # FIXME: find requests that have this project as a source or target and remove them
      # FIXME: find all requests which have a by_project review and remove them
      # FIXME: same for by_package review of all packages in this project

      DbProject.transaction do
        logger.info "destroying project object #{pro.name}"
        pro.destroy

        params[:user] = @http_user.login
        path = "/source/#{pro.name}"
        path << build_query_from_hash(params, [:user, :comment])
        Suse::Backend.delete "/source/#{pro.name}"
        logger.debug "delete request to backend: #{path}"
      end

      render_ok
      return
    # /if request.delete?

    # POST /source/:project
    #----------------------
    elsif request.post?
      # command: undelete
      if 'undelete' == command
        unless @http_user.can_create_project?(project_name) and pro.nil?
          render_error :status => 403, :errorcode => "cmd_execution_no_permission1",
            :message => "no permission to execute command '#{command}'"
          return
        end
        dispatch_command
        return
      end

      if 'copy' == command
        unless @http_user.can_create_project?(project_name) and pro.nil?
          render_error :status => 403, :errorcode => "cmd_execution_no_permission1",
            :message => "no permission to execute command '#{command}'"
          return
        end
        dispatch_command
        return
      end

      pro = DbProject.get_by_name project_name
      # command: showlinked, set_flag, remove_flag, ...?
      if command == "showlinked" or @http_user.can_modify_project?(pro)
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
    valid_commands=['diff', 'branch', 'linkdiff', 'showlinked', 'copy', 'remove_flag', 'set_flag', 
                    'rebuild', 'undelete', 'wipe', 'runservice', 'commit', 'commitfilelist', 
                    'createSpecFileTemplate', 'deleteuploadrev', 'linktobranch', 'getprojectservices']
    # list of commands which are allowed even when the project has the package only via a project link
    read_commands = ['diff', 'linkdiff', 'showlinked', 'getprojectservices']
    source_untouched_commands = ['diff', 'linkdiff', 'showlinked', 'rebuild', 'wipe', 'remove_flag', 'set_flag', 'getprojectservices']
    # list of cammands which create the target package
    package_creating_commands = [ 'branch', 'copy', 'undelete' ]
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
    spkg = DbPackage.get_by_project_and_name origin_project_name, origin_package_name if origin_package_name and not [ '_project', '_pattern' ].include? origin_package_name
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
    else
      follow_project_links = false
      follow_project_links = true if request.get? or (source_untouched_commands.include? command)

      if [ '_project', '_pattern' ].include? target_package_name
        tprj = DbProject.get_by_name target_project_name
      else
        tpkg = DbPackage.get_by_project_and_name(target_project_name, target_package_name, use_source = true, follow_project_links = follow_project_links)
        tprj = tpkg.db_project unless tpkg.nil? # for remote package case
        if request.delete? or (request.post? and not read_commands.include? command)
          unless @http_user.can_modify_package?(tpkg)
            render_error :status => 403, :errorcode => "cmd_execution_no_permission",
              :message => "no permission to execute command '#{command}' for package #{tpkg.name}"
            return
          end
        end
      end

    end

    # check read access rights when the package does not exist anymore
    if tpkg.nil? and deleted_package
      raise DbProject::ReadAccessError, "#{target_project_name}" if tprj.nil? or tprj.disabled_for? 'access', nil, nil
      raise DbPackage::ReadSourceAccessError, "#{target_project_name}/#{target_package_name}" if tprj.disabled_for? 'sourceaccess', nil, nil

      unless tpkg
        # load last package meta file and just check if sourceaccess flag was used at all, no per user checking atm
        begin
          r = Suse::Backend.get("/source/#{CGI.escape(target_project_name)}/#{target_package_name}/_history?deleted=1&meta=1")
        rescue
          raise DbPackage::UnknownObjectError, "#{target_project_name}/#{target_package_name}"
        end

        data = ActiveXML::XMLNode.new(r.body.to_s)
        lastrev = nil
        data.each_revision {|rev| lastrev = rev}
        srcmd5 = lastrev.value("srcmd5")
        metapath = "/source/#{CGI.escape(target_project_name)}/#{target_package_name}/_meta?rev=#{srcmd5}"
        r = Suse::Backend.get(metapath)
        raise DbPackage::UnknownObjectError, "#{target_project_name}/#{target_package_name}" unless r
        dpkg = Package.new(r.body)
        raise DbPackage::UnknownObjectError, "#{target_project_name}/#{target_package_name}" unless dpkg
        raise DbPackage::ReadAccessError, "#{target_project_name}/#{target_package_name}" if dpkg.disabled_for? 'access'
        raise DbPackage::ReadSourceAccessError, "#{target_project_name}/#{target_package_name}" if dpkg.disabled_for? 'sourceaccess'
      end
    end
    
    # GET /source/:project/:package
    #------------------------------
    if request.get?

      # exec
      path = request.path
      path << build_query_from_hash(params, [:rev, :linkrev, :emptylink, :expand, :view, :extension, :lastworking, :withlinked, :meta, :deleted])
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
      unless tpkg.develpackages.empty?
        msg = "Unable to delete package #{tpkg.name}; following packages use this package as devel package: "
        msg += tpkg.develpackages.map {|dp| dp.db_project.name+"/"+dp.name}.join(", ")
        render_error :status => 400, :errorcode => 'develpackage_dependency',
          :message => msg
        return
      end

      #FIXME: Check for all requests that have this packae as either source or target
      #FIXME: Checkk all requests in state review that have a by_package review on this one

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
      @attribute_container = DbProject.get_by_name(params[:project])
    end
    # is the attribute type defined at all ?
    if params[:attribute]
      # Valid attribute
      aname = params[:attribute]
      name_parts = aname.split(/:/)
      if name_parts.length != 2
        raise ArgumentError, "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
      end
      # existing ?
      at = AttribType.find_by_name(params[:attribute])
      unless at
        render_error :status => 403, :errorcode => "not_existing_attribute",
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
      ac = @attribute_container.find_attribute(name_parts[0], name_parts[1],binary)

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
      @attribute_container.store
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
        req.data # trigger XML parsing
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
      @attribute_container.store
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

      # Need permission
      logger.debug "Checking permission for the put"
      if prj
        # project exists, change it
        unless @http_user.can_modify_project? prj
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
      rdata = REXML::Document.new(request.raw_post.to_s)
      rdata.elements.each("project/link") do |e|
        # permissions check
        tproject_name = e.attributes["project"]
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
      rdata.elements.each("project/repository/path") do |e|
        # permissions check
        tproject_name = e.attributes["project"]
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
      if prj
        prj.repositories.each do |repo|
          if rdata.elements.each("project/repository/@name=#{CGI.escape(repo.name)}").length == 0 and not repo.remote_project_name
            repo.linking_repositories.each do |lrep|
              removedRepositories << lrep
            end
          end
        end
      end
      if removedRepositories.length > 0
        if params[:force] and not params[:force].empty?
          # replace links to this projects with links to the "deleted" project
          del_repo = DbProject.find_by_name("deleted").repositories[0]
          removedRepositories.each do |link_rep|
            link_rep.path_elements.find(:all).each { |pe| pe.destroy }
            link_rep.path_elements.create(:link => del_repo, :position => 1)
            link_rep.save
            # update backend
            link_rep.db_project.store
          end
        else
          lrepstr = removedRepositories.map{|l| l.db_project.name+'/'+l.name}.join "\n"
          render_error :status => 400, :errorcode => "repo_dependency",
            :message => "Unable to delete repository; following repositories depend on this project:\n#{lrepstr}\n"
          return
        end
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
      unless @http_user.can_modify_project?(prj)
        render_error :status => 403, :errorcode => 'delete_project_pubkey_no_permission',
          :message => "No permission to delete public key for project '#{params[:project]}'"
        return
      end

      pass_to_backend path
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

      if( pkg_xml.name != package_name )
        render_error :status => 400, :errorcode => 'package_name_mismatch',
          :message => "package name in xml data does not match resource path component"
        return
      end

      # check for project
      if DbPackage.exists_by_project_and_name( project_name, package_name, follow_project_links=false )
        pkg = DbPackage.get_by_project_and_name( project_name, package_name, use_source=false )
        unless @http_user.can_modify_package?(pkg)
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
    path = "/source/#{URI.escape(project_name)}/#{URI.escape(package_name)}/#{URI.escape(file)}"

    #authenticate
    return unless @http_user
    params[:user] = @http_user.login

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

      unless params.has_key? :deleted and ["_history",].include?(file)
        if pack.nil? and request.get?
          # Check if this is a package on a remote OBS instance
          answer = Suse::Backend.get(request.path)
          if answer
            pass_to_backend
            return
          end
        end

      end
    end

    # GET /source/:project/:package/:file
    if request.get?
      if pack # local package
        path = "/source/#{URI.escape(pack.db_project.name)}/#{URI.escape(pack.name)}/#{URI.escape(file)}"
      end
      path += build_query_from_hash(params, [:rev, :meta, :deleted])
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
         validator = Suse::Validator.new( "link" )
         validator.validate(request)
      elsif params[:file] == "_aggregate"
         validator = Suse::Validator.new( "aggregate" )
         validator.validate(request)
      elsif params[:package] == "_pattern"
         validator = Suse::Validator.new( "pattern" )
         validator.validate(request)
      end

      if params[:file] == "_link"
        data = REXML::Document.new(request.raw_post.to_s)
        data.elements.each("link") do |e|
          tproject_name = e.attributes["project"]
          tpackage_name = e.attributes["package"]
          tproject_name = project_name if tproject_name.blank?
          tpackage_name = package_name if tpackage_name.blank?
          tpkg = DbPackage.get_by_project_and_name(tproject_name, tpackage_name)
        end
      end

      # _pattern was not a real package in former OBS 2.0 and before, so we need to create the
      # package here implicit to stay api compatible.
      # FIXME3.0: to be revisited
      if package_name == "_pattern" and not DbPackage.exists_by_project_and_name( project_name, package_name, follow_project_links=false )
        pack = DbPackage.new(:name => "_pattern", :title => "Patterns", :description => "Package Patterns")
        prj.db_packages << pack
        pack.save
      else
        if package_name == "_project"
          # TO BE IMPLEMENTED: add support for project update_timestamp
        else
          pack = DbPackage.get_by_project_and_name( project_name, package_name, use_source=false, follow_project_links=false )
          pack.update_timestamp
        end
      end

      pass_to_backend path

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
        pack.update_timestamp
      end
      if package_name == "_product"
        update_product_autopackages params[:project]
      end
      render_ok
    end
  end

  private

  # POST /source?cmd=createmaintenanceincident
  def index_createmaintenanceincident
    # set defaults
    unless params[:attribute]
      params[:attribute] = "OBS:MaintenanceProject"
    end

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

    # create incident project
    incident = create_new_maintenance_incident(prj)
    render_ok :data => {:targetproject => incident.db_project.name}
  end

  # POST /source?cmd=branch (aka osc mbranch)
  def index_branch
    # set defaults
    unless params[:attribute]
      params[:attribute] = "OBS:Maintained"
    end
    unless params[:update_project_attribute]
      params[:update_project_attribute] = "OBS:UpdateProject"
    end
    unless params[:target_project]
      if params[:request]
        params[:target_project] = "home:#{@http_user.login}:branches:REQUEST_#{params[:request]}"
      else
        params[:target_project] = "home:#{@http_user.login}:branches:#{params[:attribute].gsub(':', '_')}"
        params[:target_project] += ":#{params[:package]}" if params[:package]
      end
    end

    # find packages to be branched
    @packages = []
    if params[:request]
      # find packages from request
      data = Suse::Backend.get("/request/#{params[:request]}").body
      req = BsRequest.new(data)

      req.each_action do |action|
        prj=nil
        pkg=nil
        if action.has_element? 'source'
          if action.source.has_attribute? 'package'
            pkg = DbPackage.get_by_project_and_name action.source.project, action.source.package
          elsif action.source.has_attribute? 'project'
            prj = DbProject.get_by_name action.source.project
          end
        end

        @packages.push({ :target_project => pkg.db_project, :package => pkg }) unless pkg.nil?
      end
    else
      # find packages via attributes
      at = AttribType.find_by_name(params[:attribute])
      unless at
        render_error :status => 403, :errorcode => 'not_found',
          :message => "The given attribute #{params[:attribute]} does not exist"
        return
      end
      if params[:value]
        DbPackage.find_by_attribute_type_and_value( at, params[:value], params[:package] ) do |pkg|
          @packages.push({ :target_project => pkg.db_project, :package => pkg }) if @http_user.can_access? pkg.db_project
        end
        # FIXME: how to handle linked projects here ? shall we do at all or has the tagger (who creates the attribute) to create the package instance ?
      else
        # Find all direct instances of a package
        DbPackage.find_by_attribute_type( at, params[:package] ).each do |pkg|
          @packages.push({ :target_project => pkg.db_project, :package => pkg })
        end
        # Find all indirect instance via project links, a new package will get created on submit accept
        if params[:package]
          projects = DbProject.find_by_attribute_type( at )
          projects.each do |prj|
            unless @packages.map {|p| p[:target_project] }.include? prj # avoid double instance from direct found packages
              prj.linkedprojects.each do |lprj|
                if lprj.linked_db_project
                  if pkg = lprj.linked_db_project.db_packages.find_by_name( params[:package] )
                    @packages.push({ :target_project => prj, :package => pkg }) unless pkg.db_project.disabled_for? 'access', nil, nil and not @http_user.can_access? pkg.db_project
                  else
                    # FIXME: add support for branching from remote projects
                  end
                end
              end
            end
          end
        end
      end
    end

    # check for source access permission. Hidden projects must not exist here anymore!
    @packages.each do |p|
      DbPackage.get_by_project_and_name( p[:package].db_project.name, p[:package].name )
    end

    unless @packages.length > 0
      render_error :status => 403, :errorcode => "not_found",
        :message => "no packages found by search criteria"
      return
    end

    #create branch project
    unless DbProject.exists_by_name params[:target_project]
       # permission check
       unless @http_user.can_create_project?(params[:target_project])
         render_error :status => 403, :errorcode => "create_project_no_permission",
           :message => "no permission to create project '#{params[:target_project]}' while executing branch command"
         return
       end

      title = "Branch project for package #{params[:package]}"
      description = "This project was created for package #{params[:package]} via attribute #{params[:attribute]}"
      if params[:request]
        title = "Branch project based on request #{params[:request]}"
        description = "This project was created as a clone of request #{params[:request]}"
      end
      DbProject.transaction do
        tprj = DbProject.new :name => params[:target_project], :title => title, :description => description
        tprj.add_user @http_user, "maintainer"
        tprj.flags.create( :position => 1, :flag => 'build', :status => "disable" )
        tprj.store
      end
      if params[:request]
        ans = AttribNamespace.find_by_name "OBS"
        at = AttribType.find( :first, :joins => ans, :conditions=>{:name=>"RequestCloned"} )

        tprj = DbProject.get_by_name params[:target_project]
        a = Attrib.new(:db_project => tprj, :attrib_type => at)
        a.values << AttribValue.new(:value => params[:request], :position => 1)
        a.save
      end
    end

    tprj = DbProject.get_by_name params[:target_project]
    unless @http_user.can_modify_project?(tprj)
      render_error :status => 403, :errorcode => "modify_project_no_permission",
        :message => "no permission to modify project '#{params[:target_project]}' while executing branch project command"
      return
    end

    # create package branches
    # collect also the needed repositories here
    @packages.each do |p|
      # is a update project defined and a package there ?
      pac = p[:package]
      prj = pac.db_project
      aname = params[:update_project_attribute]
      name_parts = aname.split(/:/)
      if name_parts.length != 2
        raise ArgumentError, "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
      end

      # find origin package to be branched
      branch_target_project = p[:target_project].name
      branch_target_package = pac.name
      proj_name = branch_target_project.gsub(':', '_')
      pack_name = branch_target_package.gsub(':', '_') + "." + proj_name

      # check for update project
      if not params[:request] and a = p[:target_project].find_attribute(name_parts[0], name_parts[1]) and a.values[0]
        if DbPackage.exists_by_project_and_name( a.values[0].value, p[:package].name, follow_project_links=false )
          pac = DbPackage.get_by_project_and_name( a.values[0].value, p[:package].name, follow_project_links=false )
          prj = pac.db_project
          branch_target_project = pac.db_project.name
          branch_target_project = pac.db_project.name
          branch_target_package = pac.name
        else
          # package exists not yet in update project, but it may have a project link ?
          if DbPackage.exists_by_project_and_name( a.values[0].value, p[:package].name, follow_project_links=true )
            prj = DbProject.get_by_name(a.values[0].value)
            branch_target_project = a.values[0].value
          else
            render_error :status => 404, :errorcode => "unknown_package",
              :message => "branch source package does not exist in UpdateProject #{a.values[0].value}. Missing project link ?"
            return
          end
        end
      end

      # create branch package
      # no find_package call here to check really this project only
      if tpkg = tprj.db_packages.find_by_name(pack_name)
        render_error :status => 400, :errorcode => "double_branch_package",
          :message => "branch target package already exists: #{tprj.name}/#{tpkg.name}"
        return
      else
        tpkg = tprj.db_packages.new(:name => pack_name, :title => pac.title, :description => pac.description)
        tprj.db_packages << tpkg
      end

      # create repositories, if missing
      prj.repositories.each do |repo|
        repoName = proj_name+"_"+repo.name
        unless tprj.repositories.find_by_name(repoName)
          trepo = tprj.repositories.create :name => repoName
          trepo.architectures = repo.architectures
          trepo.path_elements.create(:link => repo, :position => 1)
        end
        tpkg.flags.create( :position => 1, :flag => 'build', :status => "enable", :repo => repoName )
      end
      tpkg.store

      # branch sources in backend
      Suse::Backend.post "/source/#{tpkg.db_project.name}/#{tpkg.name}?cmd=branch&oproject=#{CGI.escape(branch_target_project)}&opackage=#{CGI.escape(branch_target_package)}", nil
    end

    # store project data in DB and XML
    tprj.store

    # all that worked ? :)
    render_ok :data => {:targetproject => params[:target_project]}
  end

  # create a id collection of all projects doing a project link to this one
  # POST /source/<project>?cmd=showlinked
  def index_project_showlinked
    valid_http_methods :post
    project_name = params[:project]

    pro = DbProject.get_by_name(project_name)

    builder = FasterBuilder::XmlMarkup.new( :indent => 2 )
    xml = builder.collection() do |c|
      pro.find_linking_projects.each do |l|
        p={}
        p[:name] = l.name
        c.project(p)
      end
    end
    render :text => xml.target!, :content_type => "text/xml"
  end

  # POST /source/<project>?cmd=extendkey
  def index_project_extendkey
    valid_http_methods :post
    params[:user] = @http_user.login
    project_name = params[:project]

    pro = DbProject.find_by_name project_name

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path
  end

  # POST /source/<project>?cmd=createkey
  def index_project_createkey
    valid_http_methods :post
    params[:user] = @http_user.login
    project_name = params[:project]

    pro = DbProject.find_by_name project_name

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path
  end

  # POST /source/<project>?cmd=undelete
  def index_project_undelete
    valid_http_methods :post
    params[:user] = @http_user.login
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
    params[:user] = @http_user.login
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
      p.flags.create( :status => "disable", :flag => 'build')
      p.flags.create( :status => "disable", :flag => 'publish')
      oprj.flags.each do |f|
        p.flags.create(:status => f.status, :flag => f.flag) if f.flag == "access" or f.flag == "sourceaccess"
      end
      oprj.repositories.each do |repo|
        r = p.repositories.create :name => repo.name
        r.architectures = repo.architectures
        r.path_elements << PathElement.new(:link => repo, :position => 1)
      end
      p.store
    end

    # copy entire project in the backend
    begin
      path = request.path
      path << build_query_from_hash(params, [:cmd, :user, :comment, :oproject, :withbinaries, :withhistory])
      pass_to_backend path
    rescue
      # we need to check results of backend in any case (also timeout error eg)
    end

    # restore all package meta data objects in DB
    backend_pkgs = Collection.find :package, :match => "@project='#{project_name}'"
    backend_pkgs.each_package do |package|
      path = request.path + "/" + package.name + "/_meta"
      Package.new(backend_get(path), :project => project_name).save
    end
  end

  # POST /source/<project>?cmd=createpatchinfo
  def index_project_createpatchinfo
    project_name = params[:project]
    new_format = params[:new_format]

    pro = DbProject.find_by_name project_name

    name=nil
    maintenanceID=nil
    pkg_name = "_patchinfo:"
    pkg_name = "patchinfo" if new_format
    if new_format
      if MaintenanceIncident.count( :conditions => ["db_project_id = BINARY ?", pro.id] )
        # this is a maintenance project, the sub project name is the maintenance ID
        maintenanceID = pro.name.gsub(/.*:/, '')
      end
    elsif params[:name]
      name=params[:name]
      pkg_name = "_patchinfo:" + name
    else
      name=DbProject.find_by_name( params[:project] ).db_packages[0].name
      name.gsub!(/\..*/, '')
      pkg_name = "_patchinfo:" + name
    end
    patchinfo_path = "#{request.path}/#{pkg_name}"

    # FIXME: check for still building packages

    # create patchinfo package
    if not DbPackage.exists_by_project_and_name( params[:project], pkg_name )
      prj = DbProject.find_by_name( params[:project] )
      pkg = DbPackage.new(:name => pkg_name, :title => "Patchinfo", :description => "Collected packages for update")
      prj.db_packages << pkg
      pkg.add_flag("build", "enable", nil, nil)
      pkg.store
    else
      # shall we do a force check here ?
    end

    # request binaries in project from backend
    binaries = Array.new
    unless new_format
      binaries = list_all_binaries_in_path("/build/#{params[:project]}")

      if binaries.length < 1 and not params[:force]
        render_error :status => 400, :errorcode => "no_matched_binaries",
          :message => "No binary packages were found in project repositories"
        return
      end
    end

    # create patchinfo XML file
    node = Builder::XmlMarkup.new(:indent=>2)
    attrs = { }
    attrs[:incident] = maintenanceID if maintenanceID 
    attrs[:name] = name if name 
    xml = node.patchinfo(attrs) do |n|
      binaries.each do |binary|
        node.binary(binary)
      end
      node.packager    @http_user.login
      node.bugzilla    ""
      node.category    ""
      node.rating      ""
      node.summary     ""
      node.description ""
      # FIXME add all bugnumbers from attributes
    end
    p={ :user => @http_user.login, :comment => "generated by createpatchinfo call" }
    patchinfo_path << "/_patchinfo"
    patchinfo_path << build_query_from_hash(p, [:user, :comment])
    backend_put( patchinfo_path, xml )

    render_ok :data => {:targetproject => pro.name, :targetpackage => pkg_name}
  end

  def list_all_binaries_in_path path
    d = backend_get(path)
    data = REXML::Document.new(d)
    binaries = []

    data.elements.each("directory/entry") do |e|
      name = e.attributes["name"]
      list_all_binaries_in_path("#{path}/#{name}").each do |l|
        binaries.push( l )
      end
    end
    data.elements.each("binarylist/binary") do |b|
      name = b.attributes["filename"]
      # strip main name from binary
      # patchinfos are only designed for rpms so far
      binaries.push( name.sub(/-[^-]*-[^-]*.rpm$/, '' ) )
    end

    binaries.uniq!
    return binaries
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

    builder = FasterBuilder::XmlMarkup.new( :indent => 2 )
    xml = builder.collection() do |c|
      pack.find_linking_packages.each do |l|
        p={}
        p[:project] = l.db_project.name
        p[:name] = l.name
        c.package(p)
      end
    end
    render :text => xml.target!, :content_type => "text/xml"
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
    pack.update_timestamp if pack # in case of _project package

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
    pass_to_backend path
    
    pack = DbPackage.find_by_project_and_name( params[:project], params[:package] )
    pack.update_timestamp if pack # in case of _project package

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
    path << build_query_from_hash(params, [:cmd, :rev, :oproject, :opackage, :orev, :expand, :unified, :linkrev, :olinkrev, :missingok, :meta])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=linkdiff
  def index_package_linkdiff
    valid_http_methods :post

    path = request.path
    path << build_query_from_hash(params, [:rev, :unified, :linkrev])
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
    else
      tpkg.update_timestamp
    end

    # We need to use the project name of package object, since it might come via a project linked project
    path = "/source/#{CGI.escape(tpkg.db_project.name)}/#{CGI.escape(tpkg.name)}"
    path << build_query_from_hash(params, [:cmd, :rev, :user, :comment, :oproject, :opackage, :orev, :expand, :keeplink, :repairlink, :linkrev, :olinkrev, :requestid, :dontupdatesource])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=runservice
  def index_package_runservice
    valid_http_methods :post
    params[:user] = @http_user.login

    pack = DbPackage.find_by_project_and_name( params[:project], params[:package] )
    pack.update_timestamp

    path = request.path
    path << build_query_from_hash(params, [:cmd, :comment])
    pass_to_backend path
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
    pkg.update_timestamp

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

    render_ok
  end

  # POST /source/<project>/<package>?cmd=branch&target_project="optional_project"&target_package="optional_package"&update_project_attribute="alternative_attribute"&comment="message"
  def index_package_branch
    valid_http_methods :post
    params[:user] = @http_user.login
    prj_name = params[:project]
    pkg_name = params[:package]
    pkg_rev = params[:rev]
    target_project = params[:target_project]
    target_package = params[:target_package]
    if not params[:update_project_attribute]
      params[:update_project_attribute] = "OBS:UpdateProject"
    end
    logger.debug "branch call of #{prj_name} #{pkg_name}"

    prj = DbProject.get_by_name prj_name
    
    if prj.class == DbProject
      pkg = prj.find_package( pkg_name )
      if pkg.nil?
        # Check if this is a package via project link to a remote OBS instance
        answer = Suse::Backend.get("/source/#{CGI.escape(prj.name)}/#{CGI.escape(pkg_name)}")
        unless answer
          render_error :status => 404, :errorcode => 'unknown_package',
            :message => "Unknown package #{pkg_name} in project #{prj.name}"
          return
        end
      end
    end

    # is a update project defined and a package there ?
    aname = params[:update_project_attribute]
    name_parts = aname.split(/:/)
    if name_parts.length != 2
      raise ArgumentError, "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
    end

    if prj.class == DbProject and a = prj.find_attribute(name_parts[0], name_parts[1]) and a.values[0]
      if pa = DbPackage.find_by_project_and_name( a.values[0].value, pkg.name )
        # We have a package in the update project already, take that
        pkg = pa
        prj = pkg.db_project
        logger.debug "branch call found package in update project #{prj.name}"
      else
        update_prj = DbProject.find_by_name( a.values[0].value )
        if update_prj
          update_pkg = update_prj.find_package( pkg.name )
          if update_pkg
            # We have no package in the update project yet, but sources are reachable via project link
            pkg = update_pkg
            prj = update_prj
          end
        end
      end
    end

    # validate and resolve devel package or devel project definitions
    if not params[:ignoredevel] and pkg and ( pkg.develproject or pkg.develpackage )
      pkg = pkg.resolve_devel_package
      prj = pkg.db_project
      logger.debug "devel project is #{prj.name} #{pkg.name}"
    end

    # link against srcmd5 instead of plain revision
    unless pkg_rev.nil?
      begin
        dir = Directory.find({ :project => params[:project], :package => params[:package], :rev => params[:rev]})
      rescue
        render_error :status => 400, :errorcode => 'invalid_filelist',
          :message => "no such revision"
        return
      end
      if dir.has_attribute? 'srcmd5'
        pkg_rev = dir.srcmd5
      else
        render_error :status => 400, :errorcode => 'invalid_filelist',
          :message => "no srcmd5 revision found"
        return
      end
    end
 
    oprj_name = "home:#{@http_user.login}:branches:#{prj_name}"
    oprj_name = "home:#{@http_user.login}:branches:#{prj.name}" if prj.class == DbProject
    opkg_name = pkg_name
    opkg_name = pkg.name if pkg
    oprj_name = target_project unless target_project.nil?
    opkg_name = target_package unless target_package.nil?

    #create branch container
    oprj = DbProject.find_by_name oprj_name
    raise IllegalRequestError.new "invalid_project_name" unless valid_project_name?(oprj_name)
    if oprj.nil?
      unless @http_user.can_create_project?(oprj_name)
        render_error :status => 403, :errorcode => "create_project_no_permission",
          :message => "no permission to create project '#{oprj_name}' while executing branch command"
        return
      end

      DbProject.transaction do
        oprj = DbProject.new :name => oprj_name, :title => "Branch of #{prj_name}"
        oprj.add_user @http_user, "maintainer"
        if prj.class == DbProject
          prj.repositories.each do |repo|
            orepo = oprj.repositories.create :name => repo.name
            orepo.architectures = repo.architectures
            orepo.path_elements << PathElement.new(:link => repo, :position => 1)
          end
          # take over flags, but explicit disable publishing by default and enable building.
          prj.flags.each do |f|
            oprj.flags.create(:status => f.status, :flag => f.flag, :architecture => f.architecture, :repo => f.repo) unless f.flag == "publish" or f.flag == "build"
          end
          oprj.flags.create( :status => "disable", :flag => 'publish')
        else
          # FIXME: support this also for remote projects
        end
        oprj.store
      end
    end

    #create branch package
    unless valid_package_name? opkg_name
      render_error :status => 400, :errorcode => "invalid_package_name",
        :message => "invalid package name '#{opkg_name}'"
    end
    if opkg = oprj.db_packages.find_by_name(opkg_name)
      if params[:force]
        # shall we clean all files here ?
      else
        render_error :status => 400, :errorcode => "double_branch_package",
          :message => "branch target package already exists: #{oprj_name}/#{opkg_name}"
        return
      end
      unless @http_user.can_modify_package?(opkg)
        render_error :status => 403, :errorcode => "create_package_no_permission",
          :message => "no permission to create package '#{opkg_name}' for project '#{oprj_name}' while executing branch command"
        return
      end
    else
      unless @http_user.can_create_package_in?(oprj)
        render_error :status => 403, :errorcode => "create_package_no_permission",
          :message => "no permission to create package '#{opkg_name}' for project '#{oprj_name}' while executing branch command"
        return
      end

      if pkg
        opkg = oprj.db_packages.create(:name => opkg_name, :title => pkg.title, :description => params.has_key?(:comment) ? params[:comment] : pkg.description)
      else
        opkg = oprj.db_packages.create(:name => opkg_name, :description => params.has_key?(:comment) ? params[:comment] : "" )
      end
      if pkg
        # take over flags, but ignore publish and build flags (when branching from a frozen project)
        pkg.flags.each do |f|
          opkg.flags.create(:status => f.status, :flag => f.flag, :architecture => f.architecture, :repo => f.repo) unless f.flag == "publish" or f.flag == "build"
        end
      else
        # FIXME: support this also for remote projects
      end
      opkg.add_user @http_user, "maintainer"
      opkg.store
    end

    #create branch of sources in backend
    rev = ""
    if not pkg_rev.nil? and not pkg_rev.empty?
      rev = "&orev=#{pkg_rev}"
    end
    comment = params.has_key?(:comment) ? "&comment=#{CGI.escape(params[:comment])}" : ""
    if pkg
      Suse::Backend.post "/source/#{oprj_name}/#{opkg_name}?cmd=branch&oproject=#{CGI.escape(prj.name)}&opackage=#{CGI.escape(pkg.name)}#{rev}&user=#{CGI.escape(@http_user.login)}#{comment}", nil
      render_ok :data => {:targetproject => oprj_name, :targetpackage => opkg_name, :sourceproject => prj.name, :sourcepackage => pkg.name}
    else
      Suse::Backend.post "/source/#{oprj_name}/#{opkg_name}?cmd=branch&oproject=#{CGI.escape(prj_name)}&opackage=#{CGI.escape(pkg_name)}#{rev}&user=#{CGI.escape(@http_user.login)}#{comment}", nil
      render_ok :data => {:targetproject => oprj_name, :targetpackage => opkg_name, :sourceproject => prj_name, :sourcepackage => pkg_name}
    end
  end

  # POST /source/<project>/<package>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def index_package_set_flag
    valid_http_methods :post

    required_parameters :project, :package, :flag, :status

    prj_name = params[:project]
    pkg_name = params[:package]

    pkg = DbPackage.get_by_project_and_name prj_name, pkg_name, use_source=true, follow_project_links=false
    # FIXME2.2: sourceaccess flag enable/removal is not checked here

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

  def valid_project_name? name
    return true if name =~ /^\w[-_+\w\.:]*$/
    return false
  end

  def valid_package_name? name
    return true if name == "_patchinfo"
    return true if name == "_pattern"
    return true if name == "_project"
    return true if name == "_product"
    return true if name =~ /^_product:[-_+\w\.:]*$/
    return true if name =~ /^_patchinfo:[-_+\w\.:]*$/ # obsolete, just for backward compatibility
    name =~ /^\w[-_+\w\.:]*$/
  end
end
