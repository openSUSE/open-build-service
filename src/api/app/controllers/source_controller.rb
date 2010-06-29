require "rexml/document"

class SourceController < ApplicationController
  validate_action :index => :directory, :packagelist => :directory, :filelist => :directory
  validate_action :project_meta => :project, :package_meta => :package, :pattern_meta => :pattern
 
  skip_before_filter :extract_user, :only => [:file, :project_meta, :project_config] 

  def index
    projectlist
  end

  def projectlist
    if request.post?
      # a bit danguerous, never implment a command without proper permission check
      dispatch_command
    elsif request.get?
      if params[:deleted]
        pass_to_backend
      else
        @dir = Project.find :all
        render :text => @dir.dump_xml, :content_type => "text/xml"
      end
    end
  end

  def index_project
    project_name = params[:project]
    pro = DbProject.find_by_name project_name
    if pro.nil?
      unless params[:cmd] == "undelete"
        render_error :status => 404, :errorcode => 'unknown_project',
          :message => "Unknown project #{project_name}"
        return
      end
    elsif params[:cmd] == "undelete"
      render_error :status => 403, :errorcode => 'create_project_no_permission',
          :message => "Can not undelete, project exists already '#{project_name}'"
      return
    end
    
    if request.get?
      if params[:deleted]
        pass_to_backend
      else
        @dir = Package.find :all, :project => project_name
        render :text => @dir.dump_xml, :content_type => "text/xml"
      end
      return
    elsif request.delete?
      unless @http_user.can_modify_project?(pro)
        logger.debug "No permission to delete project #{project_name}"
        render_error :status => 403, :errorcode => 'delete_project_no_permission',
          :message => "Permission denied (delete project #{project_name})"
        return
      end

      #deny deleting if other packages use this as develproject
      unless pro.develpackages.empty?
        msg = "Unable to delete project #{pro.name}; following packages use this project as develproject: "
        msg += pro.develpackages.map {|pkg| pkg.db_project.name+"/"+pkg.name}.join(", ")
        render_error :status => 400, :errorcode => 'develproject_dependency',
          :message => msg
        return
      end
      #check all packages, if any get refered as develpackage
      pro.db_packages.each do |pkg|
        unless pkg.develpackages.empty?
          msg = "Unable to delete package #{pkg.name}; following packages use this package as devel package: "
          msg += pkg.develpackages.map {|dp| dp.db_project.name+"/"+dp.name}.join(", ")
          render_error :status => 400, :errorcode => 'develpackage_dependency',
            :message => msg
          return
        end
      end

      #find linking repos
      lreps = Array.new
      pro.repositories.each do |repo|
        repo.linking_repositories.each do |lrep|
          lreps << lrep
        end
      end

      if lreps.length > 0
        if params[:force] and not params[:force].empty?
          #replace links to this projects with links to the "deleted" project
          del_repo = DbProject.find_by_name("deleted").repositories[0]
          lreps.each do |link_rep|
            link_rep.path_elements.find(:all).each { |pe| pe.destroy }
            link_rep.path_elements.create(:link => del_repo, :position => 1)
            link_rep.save
            #update backend
            link_rep.db_project.store
          end
        else
          lrepstr = lreps.map{|l| l.db_project.name+'/'+l.name}.join "\n"
          render_error :status => 403, :errorcode => "repo_dependency",
            :message => "Unable to delete project #{project_name}; following repositories depend on this project:\n#{lrepstr}\n"
          return
        end
      end

      #destroy all packages
      pro.db_packages.each do |pack|
        DbPackage.transaction do
          logger.info "destroying package #{pack.name}"
          pack.destroy
        end
      end

      DbProject.transaction do
        logger.info "destroying project #{pro.name}"
        pro.destroy
        logger.debug "delete request to backend: /source/#{pro.name}"
        Suse::Backend.delete "/source/#{pro.name}"
      end

      render_ok
      return
    elsif request.post?
      cmd = params[:cmd]

      if ['undelete'].include?(cmd) 
        unless @http_user.can_create_project?(project_name)
          render_error :status => 403, :errorcode => "cmd_execution_no_permission",
            :message => "no permission to execute command '#{cmd}'"
          return
        end
        dispatch_command

        # read meta data from backend to restore database object
        path = request.path + "/_meta"
        Project.new(backend_get(path)).save

        # restore all package meta data objects in DB
        backend_pkgs = Collection.find :package, :match => "@project='#{params[:project]}'"
        backend_pkgs.each_package do |package|
          path = request.path + "/" + package.name + "/_meta"
          Package.new(backend_get(path), :project => params[:project]).save
        end
        return
      end

      if @http_user.can_modify_project?(pro)
        dispatch_command
      else
        render_error :status => 403, :errorcode => "cmd_execution_no_permission",
          :message => "no permission to execute command '#{cmd}'"
        return
      end
    else
      render_error :status => 400, :errorcode => "illegal_request",
        :message => "illegal POST request to #{request.request_uri}"
    end
  end

  def index_package
    valid_http_methods :get, :delete, :post
    project_name = params[:project]
    package_name = params[:package]
    cmd = params[:cmd]
    deleted = params[:deleted]

    prj = DbProject.find_by_name(project_name)
    unless prj
      if request.get?
        # Check if this is a package on a remote OBS instance
        answer = Suse::Backend.get(request.path)
        if answer
          pass_to_backend
          return
        end
      end
      render_error :status => 404, :errorcode => "unknown_project",
        :message => "unknown project '#{project_name}'"
      return
    end
    # look also via linked projects, package source may come from another project
    begin
      pkg = prj.find_package(package_name)
    rescue DbProject::CycleError => e
      render_error :status => 400, :errorcode => 'project_cycle', :message => e.message
      return
    end
    unless deleted.blank? and not request.delete?
      unless package_name == "_project" or pkg or DbProject.find_remote_project(project_name)
        render_error :status => 404, :errorcode => "unknown_package",
          :message => "unknown package '#{package_name}' in project '#{project_name}'"
        return
      end
    end

    if request.get?
      pass_to_backend
      return
    elsif request.delete?
      if package_name == "_project"
        render_error :status => 403, :errorcode => "delete_package_no_permission",
          :message => "_project package can not be deleted."
        return
      end

      if not @http_user.can_modify_package?(pkg)
        render_error :status => 403, :errorcode => "delete_package_no_permission",
          :message => "no permission to delete package #{package_name}"
        return
      end
      
      #deny deleting if other packages use this as develpackage
      # Shall we offer a --force option here as well ?
      # Shall we ask the other package owner accepting to be a devel package ?
      unless pkg.develpackages.empty?
        msg = "Unable to delete package #{pkg.name}; following packages use this package as devel package: "
        msg += pkg.develpackages.map {|dp| dp.db_project.name+"/"+dp.name}.join(", ")
        render_error :status => 400, :errorcode => 'develpackage_dependency',
          :message => msg
        return
      end

      DbPackage.transaction do
        pkg.destroy
        Suse::Backend.delete "/source/#{project_name}/#{package_name}"
        if package_name == "_product"
          update_product_autopackages
        end
      end
      render_ok
    elsif request.post?
      if ['undelete'].include?(cmd) 
        unless @http_user.can_modify_project?(prj)
          render_error :status => 403, :errorcode => "cmd_execution_no_permission",
            :message => "no permission to execute command '#{cmd}'"
          return
        end
        dispatch_command

        # read meta data from backend to restore database object
        path = request.path + "/_meta"
        Package.new(backend_get(path), :project => params[:project]).save
        return
      end

      if pkg.nil?
        unless @http_user.can_modify_project?(prj)
          render_error :status => 403, :errorcode => "cmd_execution_no_permission",
            :message => "no permission to execute command '#{cmd}' for not existing package"
          return
        end
      elsif not ['diff', 'branch'].include?(cmd) and not @http_user.can_modify_package?(pkg)
        render_error :status => 403, :errorcode => "cmd_execution_no_permission",
          :message => "no permission to execute command '#{cmd}'"
        return
      end
      
      dispatch_command
    end
  end

  # updates packages automatically generated in the backend after submitting a product file
  def update_product_autopackages
    backend_pkgs = Collection.find :package, :match => "@project='#{params[:project]}' and starts-with(@name,'_product:')"
    b_pkg_index = backend_pkgs.each_package.inject(Hash.new) {|hash,elem| hash[elem.name] = elem; hash}
    frontend_pkgs = DbProject.find_by_name(params[:project]).db_packages.find(:all, :conditions => "name LIKE '_product:%'")
    f_pkg_index = frontend_pkgs.inject(Hash.new) {|hash,elem| hash[elem.name] = elem; hash}

    all_pkgs = [b_pkg_index.keys, f_pkg_index.keys].flatten.uniq

    wt_state = ActiveXML::Config.global_write_through
    begin
      ActiveXML::Config.global_write_through = false
      all_pkgs.each do |pkg|
        if b_pkg_index.has_key?(pkg) and not f_pkg_index.has_key?(pkg)
          # new autopackage, import in database
          Package.new(b_pkg_index[pkg].dump_xml, :project => params[:project]).save
        elsif f_pkg_index.has_key?(pkg) and not b_pkg_index.has_key?(pkg)
          # autopackage was removed, remove from database
          f_pkg_index[pkg].destroy
        end
      end
    ensure
      ActiveXML::Config.global_write_through = wt_state
    end
  end

  # /source/:project/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  def attribute_meta
    valid_http_methods :get, :post, :delete
    params[:user] = @http_user.login if @http_user

    binary=nil
    binary=params[:binary] if params[:binary]

    if params[:package]
      @attribute_container = DbPackage.find_by_project_and_name(params[:project], params[:package])
      unless @attribute_container
        render_error :message => "Unknown package '#{params[:project]}/#{params[:package]}'",
          :status => 404, :errorcode => "unknown_package"
        return
      end
    else
      @attribute_container = DbProject.find_by_name(params[:project])
      unless @attribute_container
        render_error :message => "Unknown project '#{params[:project]}'",
          :status => 404, :errorcode => "unknown_project"
        return
      end
    end

    if request.get?
      params[:binary]=binary if binary
      render :text => @attribute_container.render_attribute_axml(params), :content_type => 'text/xml'
      return
    end

    if request.post?
      begin
        req = BsRequest.new(request.body.read)
        req.data # trigger XML parsing
      rescue ActiveXML::ParseError => e
        render_error :message => "Invalid XML",
          :status => 400, :errorcode => "invalid_xml"
        return
      end
    end

    # permission checking
    if params[:attribute]
      aname = params[:attribute]
      name_parts = aname.split(/:/)
      if name_parts.length != 2
        raise ArgumentError, "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
      end
      if a=@attribute_container.find_attribute(name_parts[0],name_parts[1],binary)
        unless @http_user.can_modify_attribute? a
          render_error :status => 403, :errorcode => "change_attribute_no_permission", 
            :message => "user #{user.login} has no permission to modify attribute"
          return
        end
      else
        unless request.post?
          render_error :status => 403, :errorcode => "not_existing_attribute", 
            :message => "Attempt to modify not existing attribute"
          return
        end
        unless @http_user.can_create_attribute_in? @attribute_container, :namespace => name_parts[0], :name => name_parts[1]
          render_error :status => 403, :errorcode => "change_attribute_no_permission", 
            :message => "user #{user.login} has no permission to change attribute"
          return
        end
      end
    else
      if request.post?
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
      else
        render_error :status => 403, :errorcode => "internal_error", 
          :message => "INTERNAL ERROR: unhandled request"
        return
      end
    end

    # execute action
    if request.post?
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
    elsif request.delete?
      @attribute_container.find_attribute(name_parts[0], name_parts[1],binary).destroy
      @attribute_container.store
      render_ok
    else
      render_error :message => "INTERNAL ERROR: Unhandled operation",
        :status => 404, :errorcode => "unknown_operation"
    end
  end

  # /source/:project/_pattern/:pattern
  def pattern_meta
    valid_http_methods :get, :put, :delete

    params[:user] = @http_user.login if @http_user
    
    @project = DbProject.find_by_name params[:project]
    unless @project
      render_error :message => "Unknown project '#{params[:project]}'",
        :status => 404, :errorcode => "unknown_project"
      return
    end

    if request.get?
      pass_to_backend
    else
      # PUT and DELETE
      permerrormsg = nil
      if request.put?
        permerrormsg = "no permission to store pattern"
      elsif request.delete?
        permerrormsg = "no permission to delete pattern"
      end

      unless @http_user.can_modify_project? @project
        logger.debug "user #{user.login} has no permission to modify project #{@project}"
        render_error :status => 403, :errorcode => "change_project_no_permission", 
          :message => permerrormsg
        return
      end
      
      path = request.path + build_query_from_hash(params, [:rev, :user, :comment])
      pass_to_backend path
    end
  end

  # GET /source/:project/_pattern
  def index_pattern
    valid_http_methods :get

    unless DbProject.find_by_name(params[:project])
      render_error :message => "Unknown project '#{params[:project]}'",
        :status => 404, :errorcode => "unknown_project"
      return
    end
    
    pass_to_backend
  end

  def project_meta
    valid_http_methods :get, :put

    project_name = params[:project]
    if project_name.nil?
      render_error :status => 400, :errorcode => 'missing_parameter',
        :message => "parameter 'project' is missing"
      return
    end

    if request.get?
      @project = DbProject.find_by_name( project_name )

      if @project
        render :text => @project.to_axml(params[:view]), :content_type => 'text/xml'
      elsif DbProject.find_remote_project(project_name)
        # project from remote buildservice, get metadata from backend
        pass_to_backend
      else
        render_error :message => "Unknown project '#{project_name}'",
          :status => 404, :errorcode => "unknown_project"
      end
      return
    end

    return unless extract_user

    #assemble path for backend
    params[:user] = @http_user.login
    path = request.path
    path += build_query_from_hash(params, [:user, :comment, :rev])

    if request.put?
      unless valid_project_name? project_name
        render_error :status => 400, :errorcode => "invalid_project_name",
          :message => "invalid project name '#{project_name}'"
        return
      end

      # Need permission
      logger.debug "Checking permission for the put"
      allowed = false
      request_data = request.raw_post

      @project = DbProject.find_by_name( project_name )
      if @project
        #project exists, change it
        unless @http_user.can_modify_project? @project
          logger.debug "user #{user.login} has no permission to modify project #{@project}"
          render_error :status => 403, :errorcode => "change_project_no_permission", 
            :message => "no permission to change project"
          return
        end
      else
        #project is new
        unless @http_user.can_create_project? project_name
          logger.debug "Not allowed to create new project"
          render_error :status => 403, :errorcode => 'create_project_no_permission',
            :message => "not allowed to create new project '#{project_name}'"
          return
        end
      end

      p = Project.new(request_data, :name => project_name)

      if p.name != project_name
        render_error :status => 400, :errorcode => 'project_name_mismatch',
          :message => "project name in xml data does not match resource path component"
        return
      end

      if (p.has_element? :remoteurl or p.has_element? :remoteproject) and not @http_user.is_admin?
        render_error :status => 403, :errorcode => "change_project_no_permission",
          :message => "admin rights are required to change remoteurl or remoteproject"
        return
      end

      p.add_person(:userid => @http_user.login) unless @project
      p.save

      render_ok
    else
      render_error :status => 400, :errorcode => 'illegal_request',
        :message => "Illegal request: POST #{request.path}"
    end
  end

  def project_config
    valid_http_methods :get, :put

    #check if project exists
    unless (@project = DbProject.find_by_name(params[:project]))
      render_error :status => 404, :errorcode => 'project_not_found',
        :message => "Unknown project #{params[:project]}"
      return
    end

    if request.get?
      path = request.path
      path += build_query_from_hash(params, [:rev])
      pass_to_backend path
      return
    end

    return unless extract_user

    #assemble path for backend
    params[:user] = @http_user.login
    path = request.path
    path += build_query_from_hash(params, [:user, :comment])

    if request.put?
      unless @http_user.can_modify_project?(@project)
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

  def project_pubkey
    valid_http_methods :get, :delete

    #assemble path for backend
    params[:user] = @http_user.login if request.delete?
    path = request.path
    path += build_query_from_hash(params, [:user, :comment, :rev])

    #check if project exists
    unless (@project = DbProject.find_by_name(params[:project]))
      render_error :status => 404, :errorcode => 'project_not_found',
        :message => "Unknown project #{params[:project]}"
      return
    end

    if request.get?
      pass_to_backend path
    elsif request.delete?
      #check for permissions
      unless @http_user.can_modify_project?(@project)
        render_error :status => 403, :errorcode => 'delete_project_pubkey_no_permission',
          :message => "No permission to delete public key for project '#{params[:project]}'"
        return
      end

      pass_to_backend path
      return
    end
  end

  def update_package_meta(project_name, package_name, request_data, user=nil, comment=nil)
    allowed = false
    # Try to fetch the package to see if it already exists
    @package = Package.find( package_name, :project => project_name )

    if @package
      # Being here means that the package already exists
      allowed = permissions.package_change? @package
      if allowed
        @package = Package.new( request_data, :project => project_name, :name => package_name )
      else
        logger.debug "user #{user} has no permission to change package #{@package}"
        render_error :status => 403, :errorcode => "change_package_no_permission",
          :message => "no permission to change package"
        return
      end
    else
      # Ok, the package is new
      allowed = permissions.package_create?( project_name )

      if allowed
        #FIXME: parameters that get substituted into the url must be specified here... should happen
        #somehow automagically... no idea how this might work
        @package = Package.new( request_data, :project => project_name, :name => package_name )
      else
        # User is not allowed by global permission.
        logger.debug "Not allowed to create new packages"
        render_error :status => 403, :errorcode => "create_package_no_permission",
          :message => "no permission to create package for project #{project_name}"
        return
      end
    end

    if allowed
      if( @package.name != package_name )
        render_error :status => 400, :errorcode => 'package_name_mismatch',
          :message => "package name in xml data does not match resource path component"
        return
      end

      begin
        @package.save
      rescue DbPackage::CycleError => e
        render_error :status => 400, :errorcode => 'devel_cycle', :message => e.message
        return
      end
      render_ok
    else
      logger.debug "user #{user} has no permission to write package meta for package #{@package}"
    end
  end
  private :update_package_meta

  def package_meta
    valid_http_methods :put, :get
   
    project_name = params[:project]
    package_name = params[:package]

    if project_name.nil?
      render_error :status => 400, :errorcode => "parameter_missing",
        :message => "parameter 'project' missing"
      return
    end

    if package_name.nil?
      render_error :status => 400, :errorcode => "parameter_missing",
        :message => "parameter 'package' missing"
      return
    end

    unless pro = DbProject.find_by_name(project_name)
      pro, pro_name = DbProject.find_remote_project(project_name)
      unless request.get? and pro
        render_error :status => 404, :errorcode => "unknown_project",
          :message => "Unknown project '#{project_name}'"
        return
      end
    end

    unless valid_package_name? package_name
      render_error :status => 400, :errorcode => "invalid_package_name",
        :message => "invalid package name '#{package_name}'"
      return
    end

    if request.get?
      begin
        pack = pro.find_package( package_name )
      rescue DbProject::CycleError => e
        render_error :status => 400, :errorcode => 'project_cycle', :message => e.message
        return
      end
      unless pack
        # check if this comes from a remote project, also true for _project package
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
      update_package_meta(project_name, package_name, request.raw_post, @http_user.login, params[:comment])
    end
  end

  def file
    valid_http_methods :get, :delete, :put
    project_name = params[:project]
    package_name = params[:package]
    file = params[:file]

    path = "/source/#{project_name}/#{package_name}/#{file}"

    if request.get?
      path += build_query_from_hash(params, [:rev, :meta])
      pass_to_backend path
      return
    end

    #authenticate
    return unless extract_user

    pack = DbPackage.find_by_project_and_name(project_name, package_name)
    if package_name == "_project"
      allowed = permissions.project_change? project_name
    else
      if pack.nil? and package_name != "_project"
        render_error :status => 403, :errorcode => 'not_found',
          :message => "The given package #{package_name} does not exist in project #{project_name}"
        return
      end
      allowed = permissions.package_change? pack
    end

    params[:user] = @http_user.login
    if request.put?
      path += build_query_from_hash(params, [:user, :comment, :rev, :linkrev, :keeplink, :meta])
      
      if  allowed
        # file validation where possible
        if params[:file] == "_link"
           validator = Suse::Validator.new( "link" )
           validator.validate(request)
        elsif params[:file] == "_aggregate"
           validator = Suse::Validator.new( "aggregate" )
           validator.validate(request)
        end

        pass_to_backend path
        pack.update_timestamp
        if package_name == "_product"
          update_product_autopackages
        end
      else
        render_error :status => 403, :errorcode => 'put_file_no_permission',
          :message => "Insufficient permissions to store file in package #{package_name}, project #{project_name}"
      end
    elsif request.delete?
      path += build_query_from_hash(params, [:user, :comment, :rev, :linkrev, :keeplink])
      
      if  allowed
        Suse::Backend.delete path
        pack = DbPackage.find_by_project_and_name(project_name, package_name)
        pack.update_timestamp
        if package_name == "_product"
          update_product_autopackages
        end
        render_ok
      else
        render_error :status => 403, :errorcode => 'delete_file_no_permission',
          :message => "Insufficient permissions to delete file"
      end
    end
  end

  private

  # POST /source?cmd=branch
  def index_branch
    # set defaults
    mparams=params
    if not params[:target_project]
      mparams[:target_project] = "home:#{@http_user.login}:branches:#{params[:attribute].gsub(':', '_')}"
      mparams[:target_project] += ":#{params[:package]}" if params[:package]
    end
    if not params[:update_project_attribute]
      params[:update_project_attribute] = "OBS:UpdateProject"
    end
    if not params[:attribute]
      params[:attribute] = "OBS:Maintained"
    end

    # permission check
    unless @http_user.can_create_project?(mparams[:target_project])
      render_error :status => 403, :errorcode => "create_project_no_permission",
        :message => "no permission to create project '#{mparams[:target_project]}' while executing branch command"
      return
    end

    # find packages
    at = AttribType.find_by_name(params[:attribute])
    if not at
      render_error :status => 403, :errorcode => 'not_found',
        :message => "The given attribute #{params[:attribute]} does not exist"
      return
    end
    if params[:value]
      @packages = DbPackage.find_by_attribute_type_and_value( at, params[:value], params[:package] )
    else
      @packages = DbPackage.find_by_attribute_type( at, params[:package] )
    end
    unless @packages.length > 0
      render_error :status => 403, :errorcode => "not_found",
        :message => "no packages could get found"
      return
    end

    #create branch project
    oprj = DbProject.find_by_name mparams[:target_project]
    if oprj.nil?
      DbProject.transaction do
        oprj = DbProject.new :name => mparams[:target_project], :title => "Branch Project _FIXME_", :description => "_FIXME_"
        oprj.add_user @http_user, "maintainer"
        oprj.build_flags.create( :position => 1, :status => "disable" )
        oprj.publish_flags.create( :position => 1, :status => "disable" )
        oprj.store
      end
    else
      unless @http_user.can_modify_project?(oprj)
        render_error :status => 403, :errorcode => "modify_project_no_permission",
          :message => "no permission to modify project '#{mparams[:target_project]}' while executing branch by attribute command"
        return
      end
    end

    # create package branches
    # collect also the needed repositories here
    @packages.each do |p|
    
      # is a update project defined and a package there ?
      pac = p
      aname = params[:update_project_attribute]
      name_parts = aname.split(/:/)
      if name_parts.length != 2
        raise ArgumentError, "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
      end

      # find origin package to be branched
      branch_target_project = pac.db_project.name
      branch_target_package = pac.name
      if a = p.db_project.find_attribute(name_parts[0], name_parts[1]) and a.values[0]
        if pa = DbPackage.find_by_project_and_name( a.values[0].value, p.name )
          pac = pa
          branch_target_project = pac.db_project.name
          branch_target_package = pac.name
        else
          # package exists not yet in update project, to be created
          branch_target_project = a.values[0].value
        end
      end
      proj_name = pac.db_project.name.gsub(':', '_')
      pack_name = pac.name.gsub(':', '_')+"."+proj_name

      # create branch package
      # no find_package call here to check really this project only
      if opkg = oprj.db_packages.find_by_name(pack_name)
        render_error :status => 400, :errorcode => "double_branch_package",
          :message => "branch target package already exists: #{oprj.name}/#{opkg.name}"
        return
      else
        opkg = oprj.db_packages.new(:name => pack_name, :title => pac.title, :description => pac.description)
        oprj.db_packages << opkg
      end

      # create repositories, if missing
      pac.db_project.repositories.each do |repo|
        orepo = oprj.repositories.create :name => proj_name+"_"+repo.name
        orepo.architectures = repo.architectures
        orepo.path_elements.create(:link => repo, :position => 1)
      end

      opkg.store

      # branch sources in backend
      Suse::Backend.post "/source/#{oprj.name}/#{opkg.name}?cmd=branch&oproject=#{CGI.escape(branch_target_project)}&opackage=#{CGI.escape(branch_target_package)}", nil
    end

    # store project data in DB and XML
    oprj.store

    # all that worked ? :)
    render_ok :data => {:targetproject => mparams[:target_project]}
  end

  # POST /source/<project>?cmd=createkey
  def index_project_createkey
    valid_http_methods :post
    params[:user] = @http_user.login

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path
  end

  # POST /source/<project>?cmd=undelete
  def index_project_undelete
    valid_http_methods :post
    params[:user] = @http_user.login

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path
  end

  # POST /source/<project>?cmd=createpatchinfo
  def index_project_createpatchinfo
    name=""
    if params[:name]
      name=params[:name] if params[:name]
    end
    pkg_name = "_patchinfo:#{name.gsub(/\W/, '_')}"
    patchinfo_path = "#{request.path}/#{pkg_name}"

    # request binaries in project from backend
    binaries = list_all_binaries_in_path("/build/#{params[:project]}")

    if binaries.length < 1 and not params[:force]
      render_error :status => 400, :errorcode => "no_matched_binaries",
        :message => "No binary packages were found in project repositories"
      return
    end

    # FIXME: check for still building packages

    # create patchinfo package
    if not DbPackage.find_by_project_and_name( params[:project], pkg_name )
      prj = DbProject.find_by_name( params[:project] )
      pkg = DbPackage.new(:name => pkg_name, :title => "Patchinfo", :description => "Collected packages for update")
      prj.db_packages << pkg
      Package.find(pkg_name, :project => params[:project]).save
      if name==""
        name=pkg_name
      end
    else
      # shall we do a force check here ?
    end

    # create patchinfo XML file
    node = Builder::XmlMarkup.new(:indent=>2)
    xml = node.patchinfo(:name => name) do |n|
      binaries.each do |binary|
        node.binary(binary)
      end
      node.packager    @http_user.login
      node.bugzilla    ""
      node.swampid     ""
      node.category    ""
      node.rating      ""
      node.summary     ""
      node.description ""
      # FIXME add all bugnumbers from attributes
    end
    backend_put( patchinfo_path+"/_patchinfo?user="+@http_user.login+"&comment=generated%20file%20by%20frontend", xml )

    render_ok
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

  # POST /source/<project>/<package>?cmd=undelete
  def index_package_undelete
    valid_http_methods :post
    params[:user] = @http_user.login

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path
  end

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

  # POST /source/<project>/<package>?cmd=rebuild
  def index_package_rebuild
    project_name = params[:project]
    package_name = params[:package]
    repo_name = params[:repo]
    arch_name = params[:arch]

    path = "/build/#{project_name}?cmd=rebuild&package=#{package_name}"
    
    p = DbProject.find_by_name project_name
    if p.nil?
      render_error :status => 400, :errorcode => 'unknown_project',
        :message => "Unknown project '#{project_name}'"
      return
    end

    begin
      pkg = find_package( p, package_name )
    rescue DbProject::CycleError => e
      render_error :status => 400, :errorcode => 'project_cycle', :message => e.message
      return
    end
    unless pkg
      render_error :status => 400, :errorcode => 'unknown_package',
        :message => "Unknown package '#{package_name}'"
      return
    end

    if repo_name
      path += "&repository=#{repo_name}"
      if p.repositories.find_by_name(repo_name).nil?
        render_error :status => 400, :errorcode => 'unknown_repository',
          :message=> "Unknown repository '#{repo_name}'"
        return
      end
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

    if params[:package] == "_product"
      update_product_autopackages
    end
  end

  # POST /source/<project>/<package>?cmd=commitfilelist
  def index_package_commitfilelist
    valid_http_methods :post
    params[:user] = @http_user.login

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment, :rev, :linkrev, :keeplink, :repairlink])
    pass_to_backend path
    
    if params[:package] == "_product"
      update_product_autopackages
    end
  end

  # POST /source/<project>/<package>?cmd=diff
  def index_package_diff
    valid_http_methods :post
    path = request.path
    path << build_query_from_hash(params, [:cmd, :rev, :oproject, :opackage, :orev, :expand, :unified, :linkrev, :olinkrev, :missingok])
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

    pack = DbPackage.find_by_project_and_name(params[:project], params[:package])
    if pack.nil? 
      render_error :status => 404, :errorcode => 'unknown_package',
        :message => "Unknown package #{params[:package]} in project #{params[:project]}"
      return
    end

    path = request.path
    path << build_query_from_hash(params, [:cmd, :rev, :user, :comment, :oproject, :opackage, :orev, :expand, :keeplink, :repairlink, :linkrev, :olinkrev, :requestid, :dontupdatesource])
    
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=runservice
  def index_package_runservice
    valid_http_methods :post
    params[:user] = @http_user.login

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

    prj = DbProject.find_by_name prj_name
    pkg = prj.db_packages.find_by_name(pkg_name)
    if pkg.nil?
      render_error :status => 404, :errorcode => 'unknown_package',
        :message => "Unknown package #{pkg_name} in project #{prj_name}"
      return
    end

    #convert link to branch
    rev = ""
    if not pkg_rev.nil? and not pkg_rev.empty?
      rev = "&rev=#{pkg_rev}"
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

    prj = DbProject.find_by_name prj_name
    if prj.nil?
      render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown project #{prj_name}"
      return
    end
    begin
      pkg = prj.find_package( pkg_name )
    rescue DbProject::CycleError => e
      render_error :status => 400, :errorcode => 'project_cycle', :message => e.message
      return
    end
    if pkg.nil?
      render_error :status => 404, :errorcode => 'unknown_package',
        :message => "Unknown package #{pkg_name} in project #{prj_name}"
      return
    end

    # is a update project defined and a package there ?
    aname = params[:update_project_attribute]
    name_parts = aname.split(/:/)
    if name_parts.length != 2
      raise ArgumentError, "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
    end

    if a = prj.find_attribute(name_parts[0], name_parts[1]) and a.values[0]
      if pa = DbPackage.find_by_project_and_name( a.values[0].value, pkg.name )
        # We have a package in the update project already, take that
        pkg = pa
        pkg_name = pkg.name
        prj = pkg.db_project
        prj_name = prj.name
    	logger.debug "branch call found package in update project #{prj_name}"
      else
        update_prj = DbProject.find_by_name( a.values[0].value )
        update_pkg = update_prj.find_package( pkg_name )
        if update_pkg
          # We have no package in the update project yet, but sources a reachable via project link
          pkg = update_pkg
          pkg_name = pkg.name
          prj = update_prj
          prj_name = prj.name
        end
      end
    end

    # validate and resolve devel package or devel project definitions
    if not params[:ignoredevel] and ( pkg.develproject or pkg.develpackage )
      pkg = pkg.resolve_devel_package
      pkg_name = pkg.name
      prj = pkg.db_project
      prj_name = prj.name
      logger.debug "devel project is #{prj_name} #{pkg_name}"
    end

    # link against srcmd5 instead of plain revision
    unless pkg_rev.nil?
      path = "/source/#{params[:project]}/#{params[:package]}" + build_query_from_hash(params, [:rev])
      files = Suse::Backend.get(path)
      # get srcmd5 from the xml data
      match = files.body.match(/<directory['"=\w\s]+srcmd5=['"](\w{32})['"]['"=\w\s]*>/)
      if match
        pkg_rev = match[1]
      else
        # this should not happen
        render_error :status => 400, :errorcode => 'invalid_filelist',
          :message => "Unable parse filelist from backend"
        return
      end
    end
 
    oprj_name = "home:#{@http_user.login}:branches:#{prj_name}"
    opkg_name = pkg_name
    oprj_name = target_project unless target_project.nil?
    opkg_name = target_package unless target_package.nil?

    #create branch container
    oprj = DbProject.find_by_name oprj_name
    if oprj.nil?
      unless @http_user.can_create_project?(oprj_name)
        render_error :status => 403, :errorcode => "create_project_no_permission",
          :message => "no permission to create project '#{oprj_name}' while executing branch command"
        return
      end

      DbProject.transaction do
        oprj = DbProject.new :name => oprj_name, :title => "Branch of #{prj.title}", :description => prj.description
        oprj.add_user @http_user, "maintainer"
        oprj.publish_flags << PublishFlag.new( :status => "disable", :position => 1 )
        prj.repositories.each do |repo|
          orepo = oprj.repositories.create :name => repo.name
          orepo.architectures = repo.architectures
          orepo.path_elements << PathElement.new(:link => repo, :position => 1)
        end
        oprj.store
      end
    end

    #create branch package
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

      opkg = oprj.db_packages.create(:name => opkg_name, :title => pkg.title, :description => params.has_key?(:comment) ? params[:comment] : pkg.description)
      opkg.add_user @http_user, "maintainer"
      opkg.store
    end

    #create branch of sources in backend
    rev = ""
    if not pkg_rev.nil? and not pkg_rev.empty?
      rev = "&rev=#{pkg_rev}"
    end
    comment = params.has_key?(:comment) ? "&comment=#{CGI.escape(params[:comment])}" : ""
    Suse::Backend.post "/source/#{oprj_name}/#{opkg_name}?cmd=branch&oproject=#{CGI.escape(prj_name)}&opackage=#{CGI.escape(pkg_name)}#{rev}&user=#{CGI.escape(@http_user.login)}#{comment}", nil

    render_ok :data => {:targetproject => oprj_name, :targetpackage => opkg_name, :sourceproject => prj_name, :sourcepackage => pkg_name}
  end

  # POST /source/<project>/<package>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def index_package_set_flag
    valid_http_methods :post

    prj_name = params[:project]
    pkg_name = params[:package]

    prj = DbProject.find_by_name prj_name
    if prj.nil?
      render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown project #{prj_name}"
      return
    end
    begin
      pkg = prj.find_package( pkg_name )
    rescue DbProject::CycleError => e
      render_error :status => 400, :errorcode => 'project_cycle', :message => e.message
      return
    end
    # first remove former flags of the same class
    pkg.remove_flag(params[:flag], params[:repository], params[:arch])
    pkg.add_flag(params[:flag], params[:status], params[:repository], params[:arch])
    pkg.store
    render_ok
  end

  # POST /source/<project>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def index_project_set_flag
    valid_http_methods :post

    prj_name = params[:project]

    prj = DbProject.find_by_name prj_name
    if prj.nil?
      render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown project #{prj_name}"
      return
    end
    # first remove former flags of the same class
    prj.remove_flag(params[:flag], params[:repository], params[:arch])
    prj.add_flag(params[:flag], params[:status], params[:repository], params[:arch])
    prj.store
    render_ok
  end

  # POST /source/<project>/<package>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def index_package_remove_flag
    valid_http_methods :post
    
    prj_name = params[:project]
    pkg_name = params[:package]

    prj = DbProject.find_by_name prj_name
    if prj.nil?
      render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown project #{prj_name}"
      return
    end
    begin
      pkg = prj.find_package( pkg_name )
    rescue DbProject::CycleError => e
      render_error :status => 400, :errorcode => 'project_cycle', :message => e.message
      return
    end
    if pkg.nil?
      render_error :status => 404, :errorcode => "unknown_package",
        :message => "unknown package '#{pkg_name}' in project '#{prj_name}'"
      return
    end
    pkg.remove_flag(params[:flag], params[:repository], params[:arch])
    pkg.store
    render_ok
  end

  # POST /source/<project>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def index_project_remove_flag
    valid_http_methods :post

    prj_name = params[:project]

    prj = DbProject.find_by_name prj_name
    if prj.nil?
      render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown project #{prj_name}"
      return
    end
    prj.remove_flag(params[:flag], params[:repository], params[:arch])
    prj.store
    render_ok
  end

  def valid_project_name? name
    name =~ /^\w[-_+\w\.:]*$/
  end

  def valid_package_name? name
    return true if name == "_pattern"
    return true if name == "_project"
    return true if name == "_product"
    return true if name =~ /^_product:[-_+\w\.:]*$/
    name =~ /^\w[-_+\w\.:]*$/
  end

end
