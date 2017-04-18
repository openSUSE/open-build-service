include MaintenanceHelper
include ValidationHelper

require 'builder/xchar'
require 'event'

class SourceController < ApplicationController

  class IllegalRequest < APIException
    setup 404, 'Illegal request'
  end

  validate_action :index => {:method => :get, :response => :directory}
  validate_action :projectlist => {:method => :get, :response => :directory}
  validate_action :packagelist => {:method => :get, :response => :directory}
  validate_action :filelist => {:method => :get, :response => :directory}
  validate_action show_project_meta: {response: :project}
  validate_action :package_meta => {:method => :get, :response => :package}

  validate_action update_project_meta: { request: :project, response: :status}
  validate_action update_package_meta: { request: :package, response: :status}

  skip_before_action :extract_user, only: [:lastevents_public]
  skip_before_action :require_login, only: [:lastevents_public]

  before_action :require_valid_project_name, except: [:index, :lastevents, :lastevents_public, :global_command]

  class NoPermissionForDeleted < APIException
    setup 403, 'only admins can see deleted projects'
  end

  # GET /source
  #########
  def index
    # init and validation
    #--------------------
    admin_user = User.current.is_admin?

    # access checks
    #--------------

    if params.has_key? :deleted
      raise NoPermissionForDeleted.new unless admin_user
      pass_to_backend
    else
      projectlist
    end
  end

  # POST /source
  def global_command
    unless %w(createmaintenanceincident branch).include? params[:cmd]
      raise UnknownCommandError.new "Unknown command '#{params[opt[:cmd_param]]}' for path #{request.path}"
    end
    dispatch_command(:global_command, params[:cmd])
  end

  def projectlist
    # list all projects (visible to user)
    output = Rails.cache.fetch(['projectlist', Project.maximum(:updated_at), User.current.forbidden_project_ids]) do
      dir = Project.pluck(:name).sort
      output = String.new
      output << "<?xml version='1.0' encoding='UTF-8'?>\n"
      output << "<directory>\n"
      output << dir.map { |item| "  <entry name=\"#{::Builder::XChar.encode(item)}\"/>\n" }.join
      output << "</directory>\n"
    end
    render xml: output
  end

  def set_issues_default
    @filter_changes = @states = nil
    @filter_changes = params[:changes].split(',') if params[:changes]
    @states = params[:states].split(',') if params[:states]
    @login = params[:login]
  end

  def render_project_issues
    set_issues_default
    render partial: 'project_issues'
  end

  # GET /source/:project
  def show_project
    project_name = params[:project]
    if params.has_key? :deleted
      unless Project.find_by_name project_name
        # project is deleted or not accessable
        validate_visibility_of_deleted_project(project_name)
      end
      pass_to_backend
      return
    end

    if Project.is_remote_project?(project_name)
      # not a local project, hand over to backend
      pass_to_backend
      return
    end

    @project = Project.find_by_name(project_name)
    raise Project::UnknownObjectError.new project_name unless @project
    # we let the backend list the packages after we verified the project is visible
    if params.has_key? :view
      if params['view'] == 'productlist'
        render xml: render_project_productlist
      elsif params['view'] == 'issues'
        render_project_issues
      else
        pass_to_backend
      end
      return
    end

    render xml: render_project_packages
  end

  def render_project_packages
    packages=nil
    if params.has_key? :expand
      packages = @project.expand_all_packages
    else
      packages = @project.packages.pluck(:name, :project_id)
    end
    packages = @project.map_packages_to_projects(packages)
    output = String.new
    output << "<directory count='#{packages.length}'>\n"
    output << packages.map { |p| p[1].nil? ? "  <entry name=\"#{p[0]}\"/>\n" : "  <entry name=\"#{p[0]}\" originproject=\"#{p[1]}\"/>\n" }.join
    output << "</directory>\n"
    output
  end

  def render_project_productlist
    products=nil
    if params.has_key? :expand
      products = @project.expand_all_products
    else
      products = Product.joins(:package).where("packages.project_id = ? and packages.name = '_product'", @project.id).pluck(:name, :cpe, :package_id)
    end
    products = @project.map_products_to_packages(products)
    output = String.new
    output << "<productlist count='#{products.length}'>\n"
    output << products.map { |p| "  <product name=\"#{p[0]}\" cpe=\"#{p[1]}\" originproject=\"#{p[2]}\" mtime=\"#{p[3]}\"/>\n" }.join
    output << "</productlist>\n"
    output
  end

  # DELETE /source/:project
  def delete_project
    project_name = params[:project]
    pro = Project.get_by_name project_name

    # checks
    unless User.current.can_modify_project?(pro)
      logger.debug "No permission to delete project #{project_name}"
      render_error :status => 403, :errorcode => 'delete_project_no_permission',
                   :message => "Permission denied (delete project #{project_name})"
      return
    end
    pro.can_be_deleted?

    # find linking repos
    private_check_and_remove_repositories(params, pro.repositories) or return

    Project.transaction do
      logger.info "destroying project object #{pro.name}"
      pro.revoke_requests
      pro.destroy

      params[:user] = User.current.login
      path = "/source/#{pro.name}"
      path << build_query_from_hash(params, [:user, :comment])
      Suse::Backend.delete path
      logger.debug "delete request to backend: #{path}"
    end

    render_ok

  end

  # POST /source/:project?cmd
  #-----------------
  def project_command

    # init and validation
    #--------------------
    valid_commands=%w(undelete showlinked remove_flag set_flag createpatchinfo createkey extendkey copy
                      createmaintenanceincident unlock release addchannels)
    if params[:cmd]
      raise IllegalRequest.new 'invalid_command' unless valid_commands.include?(params[:cmd])
      command = params[:cmd]
    end
    project_name = params[:project]
    #admin_user = User.current.is_admin?

    params[:user] = User.current.login

    if %w(undelete release copy).include? command
      return dispatch_command(:project_command, command)
    end

    @project = Project.get_by_name project_name
    # unlock
    if command == 'unlock' and User.current.can_modify_project?(@project, true)
      dispatch_command(:project_command, command)
    elsif command == 'showlinked' or User.current.can_modify_project?(@project)
      # command: showlinked, set_flag, remove_flag, ...?
      dispatch_command(:project_command, command)
    else
      raise CmdExecutionNoPermission.new "no permission to execute command '#{command}'"
    end

  end

  class NoLocalPackage < APIException; end
  class CmdExecutionNoPermission < APIException
    setup 403
  end

  def show_package_issues
    unless @tpkg
      raise NoLocalPackage.new 'Issues can only be shown for local packages'
    end
    set_issues_default
    @tpkg.update_if_dirty
    render partial: 'package_issues'
  end

  before_filter :require_package, only: [:show_package, :delete_package, :package_command]

  # GET /source/:project/:package
  def show_package
    if @deleted_package
      tpkg = Package.find_by_project_and_name(@target_project_name, @target_package_name)
      if tpkg
        raise PackageExists.new 'the package is not deleted'
      else
        validate_read_access_of_deleted_package(@target_project_name, @target_package_name)
      end
    else
      if %w(_project _pattern).include? @target_package_name
        Project.get_by_name @target_project_name
      else
        @tpkg = Package.get_by_project_and_name(@target_project_name, @target_package_name, use_source: true, follow_project_links: true)
      end
    end

    if params[:view] == 'issues'
       show_package_issues and return
    end

    # exec
    path = request.path
    path << build_query_from_hash(params, [:rev, :linkrev, :emptylink, :expand, :view, :extension, :lastworking, :withlinked, :meta, :deleted, :parse, :arch, :repository, :product])
    pass_to_backend path
  end

  class DeletePackageNoPermission < APIException
    setup 403
  end

  class PackageExists < APIException
  end

  def delete_package

    # checks
    if @target_package_name == '_project'
      raise DeletePackageNoPermission.new '_project package can not be deleted.'
    end

    tpkg = Package.get_by_project_and_name(@target_project_name, @target_package_name,
                                           use_source: false, follow_project_links: false)

    unless User.current.can_modify_package?(tpkg)
      raise DeletePackageNoPermission.new "no permission to delete package #{tpkg.name} in project #{tpkg.project.name}"
    end

    # deny deleting if other packages use this as develpackage
    # Shall we offer a --force option here as well ?
    # Shall we ask the other package owner accepting to be a devel package ?
    tpkg.can_be_deleted?

    # exec
    Package.transaction do
   
      project = nil
      project = tpkg.project if tpkg and tpkg.name == "_product"

      # we need to keep this order to delete first the api model
      tpkg.revoke_requests
      tpkg.destroy

      params[:user] = User.current
      path = tpkg.source_path
      path << build_query_from_hash(params, [:user, :comment])
      Suse::Backend.delete path

      project.update_product_autopackages if project
    end
    render_ok
  end

  # before_filter for show_package, delete_package and package_command
  def require_package
    # init and validation
    #--------------------
    #admin_user = User.current.is_admin?
    @deleted_package = params.has_key? :deleted

    # FIXME: for OBS 3, api of branch and copy calls have target and source in the opossite place
    if ['branch', 'release'].include? params[:cmd]
      @target_package_name = params[:package]
      @target_project_name = params[:target_project] # might be nil
      @target_package_name = params[:target_package] if params[:target_package]
    else
      @target_project_name = params[:project]
      @target_package_name = params[:package]
    end

  end

  class NoMatchingReleaseTarget < APIException
    setup 404, 'No defined or matching release target'
  end

  def verify_can_modify_target_package!
    unless User.current.can_modify_package?(@package)
      raise CmdExecutionNoPermission.new "no permission to execute command '#{params[:cmd]}' for package #{@package.name} in project #{@package.project.name}"
    end
  end

  # POST /source/:project/:package
  def package_command
    params[:user] = User.current.login

    unless params[:cmd]
      raise MissingParameterError.new 'POST request without given cmd parameter'
    end

    # valid post commands
    valid_commands=%w(diff branch servicediff linkdiff showlinked copy remove_flag set_flag rebuild undelete
                      wipe runservice commit commitfilelist createSpecFileTemplate deleteuploadrev linktobranch
                      updatepatchinfo getprojectservices unlock release importchannel)

    @command = params[:cmd]
    raise IllegalRequest.new 'invalid_command' unless valid_commands.include?(@command)

    origin_project_name = params[:oproject] if params[:oproject]
    origin_package_name = params[:opackage] if params[:opackage]

    if origin_package_name
      required_parameters :oproject
    end

    # Check for existens/access of origin package when specified
    @spkg = nil
    Project.get_by_name origin_project_name if origin_project_name
    if origin_package_name && !%w(_project _pattern).include?(origin_package_name) && !(params[:missingok] && [ 'branch', 'release' ].include?(@command))
      @spkg = Package.get_by_project_and_name(origin_project_name, origin_package_name)
    end
    unless Package_creating_commands.include? @command and not Project.exists_by_name(@target_project_name)
      # even when we can create the package, an existing instance must be checked if permissions are right
      @project = Project.get_by_name @target_project_name
      if not Package_creating_commands.include? @command or Package.exists_by_project_and_name( @target_project_name, @target_package_name, follow_project_links: Source_untouched_commands.include?(@command) )
        validate_target_for_package_command_exists!
      end
    end

    dispatch_command(:package_command, @command)
  end


  Source_untouched_commands = %w(branch diff linkdiff servicediff showlinked rebuild wipe remove_flag set_flag getprojectservices)
  # list of cammands which create the target package
  Package_creating_commands = %w(branch release copy undelete)
  # list of commands which are allowed even when the project has the package only via a project link
  Read_commands = %w(branch diff linkdiff servicediff showlinked getprojectservices release)

  def validate_target_for_package_command_exists!
    @project = nil
    @package = nil

    follow_project_links = Source_untouched_commands.include?(@command)

    unless %w(_project _pattern).include? @target_package_name
      use_source = true
      use_source = false if @command == 'showlinked'
      @package = Package.get_by_project_and_name(@target_project_name, @target_package_name,
                                             use_source: use_source, follow_project_links: follow_project_links)
      if @package # for remote package case it's nil
        @project = @package.project
        ignoreLock = @command == 'unlock'
        unless Read_commands.include? @command or User.current.can_modify_package?(@package, ignoreLock)
          raise CmdExecutionNoPermission.new "no permission to modify package #{@package.name} in project #{@project.name}"
        end
      end
    end

    # check read access rights when the package does not exist anymore
    if @package.nil? and @deleted_package
      validate_read_access_of_deleted_package(@target_project_name, @target_package_name)
    end
  end

  class ChangeProjectNoPermission < APIException
    setup 403
  end

  class InvalidProjectParameters < APIException
    setup 404
  end

  # GET /source/:project/_meta
  #---------------------------
  def show_project_meta
    if Project.find_remote_project params[:project]
      # project from remote buildservice, get metadata from backend
      raise InvalidProjectParameters.new if params[:view]
      pass_to_backend
    else
      # access check
      prj = Project.get_by_name params[:project]
      render xml: prj.to_axml
    end
  end

  class ProjectNameMismatch < APIException
  end

  class RepositoryAccessFailure < APIException
    setup 404
  end

  class ProjectReadAccessFailure < APIException
    setup 404
  end

  # PUT /source/:project/_meta
  def update_project_meta
    # init
    #--------------------
    project_name = params[:project]
    params[:user] = User.current.login

    # init
    # assemble path for backend
    path = request.path
    path += build_query_from_hash(params, [:user, :comment, :rev])
    #allowed = false
    request_data = request.raw_post

    # permission check
    rdata = Xmlhash.parse(request_data)
    if rdata['name'] != project_name
      raise ProjectNameMismatch.new "project name in xml data ('#{rdata['name']}) does not match resource path component ('#{project_name}')"
    end
    begin
      prj = Project.get_by_name rdata['name']
    rescue Project::UnknownObjectError
      prj = nil
    end

    # remote url project must be edited by the admin
    unless User.current.is_admin?
      if rdata.has_key? 'remoteurl' or rdata.has_key? 'remoteproject'
        raise ChangeProjectNoPermission.new 'admin rights are required to change remoteurl or remoteproject'
      end
    end

    # Need permission
    logger.debug 'Checking permission for the put'
    if prj
      # is lock explicit set to disable ? allow the un-freeze of the project in that case ...
      ignoreLock = nil
      # do not support unlock via meta data, just via command or request revoke for now
      # ignoreLock = true if rdata.has_key?("lock/disable")

      # project exists, change it
      unless User.current.can_modify_project?(prj, ignoreLock)
        if prj.is_locked?
          logger.debug "no permission to modify LOCKED project #{prj.name}"
          raise ChangeProjectNoPermission.new "The project #{prj.name} is locked"
        end
        logger.debug "user #{user.login} has no permission to modify project #{prj.name}"
        raise ChangeProjectNoPermission.new 'no permission to change project'
      end

    else
      # project is new
      unless User.current.can_create_project? project_name
        logger.debug 'Not allowed to create new project'
        raise CreateProjectNoPermission.new "no permission to create project #{project_name}"
      end
    end

    check_target_of_link(project_name, rdata)
    _update_project_meta_maintains(rdata)
    new_repo_names = _update_project_meta_repos(project_name, rdata)

    # permission check passed, write meta
    if prj
      removedRepositories = Array.new
      prj.repositories.each do |repo|
        if !new_repo_names[repo.name] and not repo.remote_project_name
          # collect repositories to remove
          removedRepositories << repo
        end
      end
      private_check_and_remove_repositories(params, removedRepositories) or return
    end

    Project.transaction do
      # exec
      unless prj
        prj = Project.new(name: project_name)
        prj.update_from_xml(rdata)
        # failure is ok
        prj.add_user(User.current.login, 'maintainer')
      else
        prj.update_from_xml(rdata)
      end
      prj.store({ :comment => params[:comment] })
    end
    render_ok
  end
  def _update_project_meta_repos(project_name, rdata)
    new_repo_names = {}
    # Check used repo pathes for existens and read access permissions
    rdata.elements('repository') do |r|
      new_repo_names[r['name']] = 1
      r.elements('path') do |e|
        # permissions check
        tproject_name = e.value('project')
        if tproject_name != project_name
          tprj = Project.get_by_name(tproject_name)
          if tprj.class == Project and tprj.disabled_for?('access', nil, nil) # user can access tprj, but backend would refuse to take binaries from there
            raise RepositoryAccessFailure.new "The current backend implementation is not using binaries from read access protected projects #{tproject_name}"
          end
        end

        logger.debug "project #{project_name} repository path checked against #{tproject_name} projects permission"
      end
    end
    new_repo_names
  end
  private :_update_project_meta_repos
  def _update_project_meta_maintains(rdata)
    # Check if used maintains statements point only to projects with write access
    rdata.elements('maintenance') do |m|
      m.elements('maintains') do |r|
        tproject_name = r.value('project')
        tprj = Project.get_by_name(tproject_name)
        unless tprj.class == Project and User.current.can_modify_project?(tprj)
          raise ModifyProjectNoPermission.new "No write access to maintained project #{tproject_name}"
        end
      end
    end
  end
  private :_update_project_meta_maintains

  # the following code checks if the target project of a linked project exists or is not readable by user
  def check_target_of_link(project_name, rdata)
    rdata.elements('link') do |e|
      # permissions check
      tproject_name = e.value('project')
      tprj = Project.get_by_name(tproject_name)

      # The read access protection for own and linked project must be the same.
      # ignore this for remote targets
      if tprj.class == Project and tprj.disabled_for?('access', nil, nil) and
          !FlagHelper.xml_disabled_for?(rdata, 'access')
        raise ProjectReadAccessFailure.new "project links work only when both projects have same read access protection level: #{project_name} -> #{tproject_name}"
      end

      logger.debug "project #{project_name} link checked against #{tproject_name} projects permission"
    end
  end

  # GET /source/:project/_config
  def show_project_config
    path = request.path
    path += build_query_from_hash(params, [:rev])
    pass_to_backend path
  end

  class PutProjectConfigNoPermission < APIException
    setup 403
  end

  # PUT /source/:project/_config
  def update_project_config
    # check for project
    prj = Project.get_by_name(params[:project])

    # assemble path for backend
    params[:user] = User.current.login

    unless User.current.can_modify_project?(prj)
      raise PutProjectConfigNoPermission.new "No permission to write build configuration for project '#{params[:project]}'"
    end

    # assemble path for backend
    path = request.path
    path += build_query_from_hash(params, [:user, :comment])

    pass_to_backend path
  end

  def pubkey_path
    # check for project
    @prj = Project.get_by_name(params[:project])
    request.path + build_query_from_hash(params, [:user, :comment, :meta, :rev])
  end

  # GET /source/:project/_pubkey and /_sslcert
  def show_project_pubkey
    # assemble path for backend
    path = pubkey_path

    # GET /source/:project/_pubkey
    pass_to_backend path
  end

  class DeleteProjectPubkeyNoPermission < APIException
    setup 403
  end

  # DELETE /source/:project/_pubkey
  def delete_project_pubkey
    params[:user] = User.current.login
    path = pubkey_path

    #check for permissions
    upperProject = @prj.name.gsub(/:[^:]*$/, '')
    while upperProject != @prj.name and not upperProject.blank?
      if Project.exists_by_name(upperProject) and User.current.can_modify_project?(Project.get_by_name(upperProject))
        pass_to_backend path
        return
      end
      if not upperProject.include? ':'
        break
      end
      upperProject = upperProject.gsub(/:[^:]*$/, '')
    end

    if User.current.is_admin?
      pass_to_backend path
    else
      raise DeleteProjectPubkeyNoPermission.new "No permission to delete public key for project '#{params[:project]}'. Either maintainer permissions by upper project or admin permissions is needed."
    end
  end

  def require_package_name
    required_parameters :project, :package

    @project_name = params[:project]
    @package_name = params[:package]

    valid_package_name! @package_name
  end

  # GET /source/:project/:package/_meta
  def show_package_meta
    require_package_name

    pack = Package.get_by_project_and_name(@project_name, @package_name, use_source: false)

    if params.has_key?(:rev) or pack.nil? # and not pro_name
                                          # check if this comes from a remote project, also true for _project package
                                          # or if rev it specified we need to fetch the meta from the backend
      answer = Suse::Backend.get(request.path)
      if answer
        render :text => answer.body.to_s, :content_type => 'text/xml'
      else
        render_error :status => 404, :errorcode => 'unknown_package',
                     :message => "Unknown package '#{@package_name}'"
      end
      return
    end

    render xml: pack.to_axml
  end

  # PUT /source/:project/:package/_meta
  def update_package_meta
    require_package_name

    rdata = Xmlhash.parse(request.raw_post)

    if rdata['project'] && rdata['project'] != @project_name
      render_error :status => 400, :errorcode => 'project_name_mismatch',
                   :message => 'project name in xml data does not match resource path component'
      return
    end

    if rdata['name'] && rdata['name'] != @package_name
      render_error :status => 400, :errorcode => 'package_name_mismatch',
                   :message => 'package name in xml data does not match resource path component'
      return
    end

    # check for project
    if Package.exists_by_project_and_name(@project_name, @package_name, follow_project_links: false)
      # is lock explicit set to disable ? allow the un-freeze of the project in that case ...
      ignoreLock = nil
      # unlock only via command for now
      #         ignoreLock = 1 if Xmlhash.parse(request.raw_post).get("lock")["disable"]

      pkg = Package.get_by_project_and_name(@project_name, @package_name, use_source: false)
      unless User.current.can_modify_package?(pkg, ignoreLock)
        render_error :status => 403, :errorcode => 'change_package_no_permission',
                     :message => "no permission to modify package '#{pkg.project.name}'/#{pkg.name}"
        return
      end

      if pkg and not pkg.disabled_for?('sourceaccess', nil, nil)
        if FlagHelper.xml_disabled_for?(rdata, 'sourceaccess')
          render_error :status => 403, :errorcode => 'change_package_protection_level',
                       :message => 'admin rights are required to raise the protection level of a package'
          return
        end
      end
    else
      prj = Project.get_by_name(@project_name)
      unless User.current.can_create_package_in?(prj)
        render_error :status => 403, :errorcode => 'create_package_no_permission',
                     :message => "no permission to create a package in project '#{@project_name}'"
        return
      end
      pkg = prj.packages.new(name: @package_name)
    end

    pkg.update_from_xml(rdata)
    render_ok
  end

  # GET /source/:project/:package/:filename
  def get_file

    project_name = params[:project]
    package_name = params[:package] || "_project"
    file = params[:filename]

    if params.has_key?(:deleted)
      if package_name == '_project'
        validate_visibility_of_deleted_project(project_name)
        pass_to_backend
        return
      end

      validate_read_access_of_deleted_package(project_name, package_name)
      pass_to_backend
      return
    end

    # a readable package, even on remote instance is enough here
    if package_name == '_project'
      Project.get_by_name(project_name)
    else
      if pack = Package.get_by_project_and_name(project_name, package_name, use_source: true)
        # in case of project links, we need to rewrite the target
        project_name = pack.project.name
        package_name = pack.name
      end
    end

    path = Package.source_path(project_name, package_name, file)
    path += build_query_from_hash(params, [:rev, :meta, :deleted, :limit, :expand])
    pass_to_backend path
  end

  class PutFileNoPermission < APIException
    setup 403
  end

  class WrongRouteForAttribute < APIException; end

  def check_permissions_for_file
    @project_name = params[:project]
    @package_name = params[:package]
    @file = params[:filename]
    @path = Package.source_path @project_name, @package_name, @file

    #authenticate
    params[:user] = User.current.login

    @prj = Project.get_by_name(@project_name)
    @pack = nil
    @allowed = false

    if @package_name == '_project' or @package_name == '_pattern'
      @allowed = permissions.project_change? @prj

      if @file == '_attribute' &&  @package_name == '_project'
        raise WrongRouteForAttribute.new "Attributes need to be changed through #{change_attribute_path(project: params[:project])}"
      end
    else
      # we need a local package here in any case for modifications
      @pack = Package.get_by_project_and_name(@project_name, @package_name)
      @allowed = permissions.package_change? @pack
    end
  end

  # PUT /source/:project/:package/:filename
  def update_file
    check_permissions_for_file

    unless @allowed
      raise PutFileNoPermission.new "Insufficient permissions to store file in package #{@package_name}, project #{@project_name}"
    end

    @path += build_query_from_hash(params, [:user, :comment, :rev, :linkrev, :keeplink, :meta])

    special_file = false

    # file validation where possible
    %w{aggregate constraints link service patchinfo channel}.each do |special|
      if params[:filename] == '_' + special
        special_file = true
        Suse::Validator.validate( special, request.raw_post.to_s)
      end
    end

    if params[:package] == '_pattern'
      Suse::Validator.validate( 'pattern', request.raw_post.to_s)
    end

    # verify link
    if params[:filename] == '_link'
      data = ActiveXML::Node.new(request.raw_post.to_s)
      if data
        tproject_name = data.value('project') || @project_name
        tpackage_name = data.value('package') || @package_name
        if data.has_attribute? 'missingok'
          Project.get_by_name(tproject_name) # permission check
          if Package.exists_by_project_and_name(tproject_name, tpackage_name, follow_project_links: true, allow_remote_packages: true)
            raise NotMissingError.new "Link contains a missingok statement but link target (#{tproject_name}/#{tpackage_name}) exists."
          end
        else
          # permission check
          Package.get_by_project_and_name(tproject_name, tpackage_name)
        end
      end
    end

    # verify channel data
    if params[:filename] == '_channel'
      Channel.verify_xml!(request.raw_post.to_s)
    end

    # verify patchinfo data
    if params[:filename] == '_patchinfo'
      Patchinfo.new.verify_data(@prj, request.raw_post.to_s)
    end

    # _pattern was not a real package in former OBS 2.0 and before, so we need to create the
    # package here implicit to stay api compatible.
    # FIXME3.0: to be revisited
    if @package_name == '_pattern' and not Package.exists_by_project_and_name( @project_name, @package_name, follow_project_links: false )
      pack = Package.new(:name => '_pattern', :title => 'Patterns', :description => 'Package Patterns')
      @prj.packages << pack
      pack.save
    end

    pass_to_backend @path

    # update package timestamp and reindex sources
    unless params[:rev] == 'repository' or %w(_project _pattern).include? @package_name
      @pack.sources_changed
      @pack.update_if_dirty if special_file # scan
    end
  end

  # DELETE /source/:project/:package/:filename
  def delete_file
    check_permissions_for_file

    @path += build_query_from_hash(params, [:user, :comment, :meta, :rev, :linkrev, :keeplink])

    unless @allowed
      raise DeleteFileNoPermission.new 'Insufficient permissions to delete file'
    end

    Suse::Backend.delete @path
    unless @package_name == '_pattern' or @package_name == '_project'
      # _pattern was not a real package in old times
      @pack.sources_changed
    end
    render_ok
  end

  # POST, GET /public/lastevents
  # GET /lastevents
  def lastevents_public
    lastevents
  end

  # POST /lastevents
  def lastevents
    path = get_request_path

    # map to a GET, so we can X-forward it
    forward_from_backend path
  end

  private

  class AttributeNotFound < APIException
    setup 'not_found', 404
  end

  class ModifyProjectNoPermission < APIException
    setup 403
  end

  # POST /source?cmd=createmaintenanceincident
  def global_command_createmaintenanceincident
    # set defaults
    unless params[:attribute]
      params[:attribute] = 'OBS:MaintenanceProject'
    end

    # find maintenance project via attribute
    at = AttribType.find_by_name(params[:attribute])
    unless at
      raise AttributeNotFound.new "The given attribute #{params[:attribute]} does not exist"
    end
    prj = Project.find_by_attribute_type( at ).first()
    actually_create_incident(prj)
  end

  def actually_create_incident(prj)
    noaccess = false
    noaccess = true if params[:noaccess]

    unless User.current.can_modify_project?(prj)
      raise ModifyProjectNoPermission.new "no permission to modify project '#{prj.name}'"
    end

    # check for correct project kind
    unless prj and prj.project_type == 'maintenance'
      render_error :status => 400, :errorcode => 'incident_has_no_maintenance_project',
                   :message => 'incident projects shall only create below maintenance projects'
      return
    end

    # create incident project
    incident = create_new_maintenance_incident(prj, nil, nil, noaccess)
    render_ok :data => {:targetproject => incident.project.name}
  end

  class RepoDependency < APIException

  end

  def check_dependent_repositories!(repos, error_prefix)
    return if repos.empty?
    lrepstr = repos.map { |l| l.project.name+'/'+l.name }.join "\n"
    raise RepoDependency.new "#{error_prefix}\n#{lrepstr}"
  end

  def private_check_and_remove_repositories( params, removeRepositories )
    # find linking repos which get deleted
    linkingRepositories = Array.new
    linkingTargetRepositories = Array.new
    removeRepositories.each do |repo|
      linkingRepositories += repo.linking_repositories
      linkingTargetRepositories += repo.linking_target_repositories
    end
    unless params[:force] and not params[:force].empty?
      check_dependent_repositories!(linkingRepositories,
                                    'Unable to delete repository; following repositories depend on this project:')
      check_dependent_repositories!(linkingTargetRepositories,
                                    'Unable to delete repository; following target repositories depend on this project:')
    end
    unless removeRepositories.empty?
      # do remove
      private_remove_repositories( removeRepositories, (params[:remove_linking_repositories] and not params[:remove_linking_repositories].empty?) )
    end
    return true
  end

  def private_remove_repositories( repositories, full_remove = false )
    del_repo = Repository.deleted_instance

    repositories.each do |repo|
      linking_repos = repo.linking_repositories
      prj = repo.project

      # full remove, otherwise the model will take care of the cleanup
      if full_remove == true
        # recursive for INDIRECT linked repositories
        unless linking_repos.length < 1
          private_remove_repositories( linking_repos, true )
        end

        # try to remove the repository 
        # but never remove the special repository named "deleted"
        unless repo == del_repo
          # permission check
          unless User.current.can_modify_project?(prj)
            raise ChangeProjectNoPermission.new "No permission to remove a repository in project '#{prj.name}'"
          end
        end
      end

      # remove this repository, but be careful, because we may have done it already.
      if Repository.exists?(repo) and r=prj.repositories.find(repo)
        logger.info "destroy repo #{r.name} in '#{prj.name}'"
        r.destroy
        prj.store({:lowprio => true}) # low prio storage
      end
    end
  end

  # POST /source?cmd=branch (aka osc mbranch)
  def global_command_branch
    private_branch_command
  end

  # create a id collection of all projects doing a project link to this one
  # POST /source/<project>?cmd=showlinked
  def project_command_showlinked
    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.collection() do |c|
      @project.find_linking_projects.each do |l|
        p={}
        p[:name] = l.name
        c.project(p)
      end
    end
    render :text => xml, :content_type => 'text/xml'
  end

  class OpenReleaseRequest < APIException
    setup 403
  end

  # unlock a project
  # POST /source/<project>?cmd=unlock
  def project_command_unlock
    required_parameters :comment

    if @project.is_maintenance_incident?
      rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
      rel = rel.where(bs_request_actions: { type: 'maintenance_release', source_project: @project.name})
      if rel.exists?
        raise OpenReleaseRequest.new "Unlock of maintenance incident #{} is not possible, because there is a running release request: #{rel.first.id}"
      end
    end

    p = { :comment => params[:comment] }

    f = @project.flags.find_by_flag_and_status('lock', 'enable')
    unless f
      render_error :status => 400, :errorcode => 'not_locked',
        :message => "project '#{@project.name}' is not locked"
      return
    end

    Project.transaction do
      @project.flags.delete(f)
      @project.store(p)

      # maintenance incidents need special treatment
      if @project.is_maintenance_incident?
        # reopen all release targets
        @project.repositories.each do |repo|
          repo.release_targets.each do |releasetarget|
            releasetarget.trigger = 'maintenance'
            releasetarget.save!
          end
        end
        @project.store(p)

        # ensure higher build numbers for re-release
        Suse::Backend.post "/build/#{URI.escape(@project.name)}?cmd=wipe", nil
      end
    end

    render_ok
  end

  # add channel packages and extend repository list
  # POST /source/<project>?cmd=addchannels
  def project_command_addchannels

    @project.packages.each do |pkg|
      pkg.add_channels
    end

    render_ok
  end

  def private_plain_backend_command
    # is there any value in this call?
    Project.find_by_name params[:project]

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path
  end

  # POST /source/<project>?cmd=extendkey
  def project_command_extendkey
    private_plain_backend_command
  end

  # POST /source/<project>?cmd=createkey
  def project_command_createkey
    private_plain_backend_command
  end

  # POST /source/<project>?cmd=createmaintenanceincident
  def project_command_createmaintenanceincident
    actually_create_incident(@project)
  end

  # POST /source/<project>?cmd=undelete
  def project_command_undelete

    unless User.current.can_create_project?(params[:project])
      raise CmdExecutionNoPermission.new "no permission to execute command 'undelete'"
    end

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path

    # read meta data from backend to restore database object
    path = request.path + '/_meta'
    prj = Project.new(name: params[:project])
    Project.transaction do
      prj.update_from_xml(Xmlhash.parse(backend_get(path)))
      prj.store
    end

    # restore all package meta data objects in DB
    backend_pkgs = Collection.find :package, :match => "@project='#{params[:project]}'"
    backend_pkgs.each('package') do |package|
      Package.transaction do
        path = Package.source_path(params[:project], package.value(:name), '_meta')
        p = Xmlhash.parse(backend_get(path))
        pkg = prj.packages.new(name: p['name'])
        pkg.update_from_xml(p)
        pkg.store
      end
    end
  end

  # POST /source/<project>?cmd=release
  def project_command_release
    params[:user] = User.current.login

    @project = Project.get_by_name params[:project], {:includeallpackages => 1}
    verify_repos_match!(@project)

    if @project.is_a? String # remote project
      render_error :status => 404, :errorcode => 'remote_project',
        :message => 'The release from remote projects is currently not supported'
      return
    end

    if params.has_key? :nodelay
      @project.do_project_release(params)
      render_ok
    else
      # inject as job
      @project.delay.do_project_release(params)
      render_invoked
    end
  end

  def verify_repos_match!(pro)
    repo_matches=nil
    pro.repositories.each do |repo|
      next if params[:repository] and params[:repository] != repo.name
      repo.release_targets.each do |releasetarget|
        unless User.current.can_modify_project?(releasetarget.target_repository.project)
          raise CmdExecutionNoPermission.new "no permission to write in project #{releasetarget.target_repository.project.name}"
        end
        unless releasetarget.trigger == 'manual'
          raise CmdExecutionNoPermission.new "Trigger is not set to manual in repository #{releasetarget.repository.project.name}/#{releasetarget.repository.name}"
        end
        repo_matches=true
      end
    end
    unless repo_matches
      raise NoMatchingReleaseTarget.new 'No defined or matching release target'
    end
  end

  class RemoteProjectError < APIException
    setup 'remote_project', 404
  end
  class ProjectCopyNoPermission < APIException
    setup 403
  end

  # POST /source/<project>?cmd=copy
  def project_command_copy
    project_name = params[:project]

    @project = Project.find_by_name(project_name)
    unless (@project and User.current.can_modify_project?(@project)) or User.current.can_create_project?(project_name)
      raise CmdExecutionNoPermission.new "no permission to execute command 'copy'"
    end
    oprj = Project.get_by_name(params[:oproject], {:includeallpackages => 1})
    if params.has_key?(:makeolder)
      unless User.current.can_modify_project?(oprj)
        raise CmdExecutionNoPermission.new "no permission to execute command 'copy', requires modification permission in oproject"
      end
    end

    if oprj.is_a? String # remote project
      raise RemoteProjectError.new 'The copy from remote projects is currently not supported'
    end

    unless User.current.is_admin?
      if params[:withbinaries]
        raise ProjectCopyNoPermission.new 'no permission to copy project with binaries for non admins'
      end

      unless oprj.is_a? String
        oprj.packages.each do |pkg|
          next unless pkg.disabled_for?('sourceaccess', nil, nil)
          raise ProjectCopyNoPermission.new "no permission to copy project due to source protected package #{pkg.name}"
        end
      end
    end

    # create new project object based on oproject
    Project.transaction do
      if oprj.is_a? String # remote project
        rdata = Xmlhash.parse(backend_get("/source/#{URI.escape(oprj)}/_meta"))
        @project = Project.new :name => project_name, :title => rdata['title'], :description => rdata['description']
      else # local project
        @project = Project.new :name => project_name, :title => oprj.title, :description => oprj.description
        @project.save
        oprj.flags.each do |f|
          @project.flags.create(:status => f.status, :flag => f.flag, :architecture => f.architecture, :repo => f.repo) unless f.flag == 'lock'
        end
        oprj.repositories.each do |repo|
          r = @project.repositories.create :name => repo.name
          repo.repository_architectures.each do |ra|
            r.repository_architectures.create! :architecture => ra.architecture, :position => ra.position
          end
          position = 0
          repo.path_elements.each do |pe|
            position += 1
            r.path_elements << PathElement.new(:link => pe.link, :position => position)
          end
        end
      end
      @project.add_user @http_user, 'maintainer'
      @project.store
    end unless @project

    if params.has_key? :nodelay
      @project.do_project_copy(params)
      render_ok
    else
      # inject as job
      @project.delay.do_project_copy(params)
      render_invoked
    end
  end

  # POST /source/<project>?cmd=createpatchinfo
  def project_command_createpatchinfo
    #project_name = params[:project]
    # a new_format argument may be given but we don't support the old (and experimental marked) format
    # anymore

    render_ok data: Patchinfo.new.create_patchinfo(params[:project], params[:name],
                                                   comment: params[:comment], force: params[:force])
  end

  # POST /source/<project>/<package>?cmd=updatepatchinfo
  def package_command_updatepatchinfo
    Patchinfo.new.cmd_update_patchinfo(params[:project], params[:package])
    render_ok
  end

  # POST /source/<project>/<package>?cmd=importchannel
  def package_command_importchannel
    repo=nil
    repo=Repository.find_by_project_and_repo_name(params[:target_project], params[:target_repository]) if params[:target_project]

    import_channel(request.raw_post, @package, repo)

    render_ok
  end

  class NotLocked < APIException; end

  # unlock a package
  # POST /source/<project>/<package>?cmd=unlock
  def package_command_unlock
    required_parameters :comment

    p = { :comment => params[:comment] }

    f = @package.flags.find_by_flag_and_status('lock', 'enable')
    raise NotLocked.new("package '#{@package.project.name}/#{@package.name}' is not locked") unless f
    @package.flags.delete(f)
    @package.store(p)

    render_ok
  end

  # Collect all project source services for a package
  # POST /source/<project>/<package>?cmd=getprojectservices
  def package_command_getprojectservices
    path = request.path
    path << build_query_from_hash(params, [:cmd])
    pass_to_backend path
  end

  # create a id collection of all packages doing a package source link to this one
  # POST /source/<project>/<package>?cmd=showlinked
  def package_command_showlinked

    unless @package
      # package comes from remote instance or is hidden

      # FIXME: return an empty list for now
      # we could request the links on remote instance via that: but we would need to search also localy and merge ...

#      path = "/search/package/id?match=(@linkinfo/package=\"#{CGI.escape(package_name)}\"+and+@linkinfo/project=\"#{CGI.escape(project_name)}\")"
#      answer = Suse::Backend.post path, nil
#      render :text => answer.body, :content_type => 'text/xml'
      render :text => '<collection/>', :content_type => 'text/xml'
      return
    end

    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.collection() do |c|
      @package.find_linking_packages.each do |l|
        p={}
        p[:project] = l.project.name
        p[:name] = l.name
        c.package(p)
      end
    end
    render :text => xml, :content_type => 'text/xml'
  end

  # POST /source/<project>/<package>?cmd=undelete
  def package_command_undelete

    if Package.exists_by_project_and_name(@target_project_name, @target_package_name, follow_project_links: false)
      raise PackageExists.new "the package exists already #{@target_project_name} #{@target_package_name}"
    end
    tprj = Project.get_by_name(@target_project_name)
    unless User.current.can_create_package_in?(tprj)
      raise CmdExecutionNoPermission.new "no permission to create package in project #{@target_project_name}"
    end

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    pass_to_backend path

    # read meta data from backend to restore database object
    path = request.path + '/_meta'
    prj = Project.find_by_name!(params[:project])
    pkg = prj.packages.new(name: params[:package])
    pkg.update_from_xml(Xmlhash.parse(backend_get(path)))
    pkg.store
  end

  # FIXME: obsolete this for 3.0
  # POST /source/<project>/<package>?cmd=createSpecFileTemplate
  def package_command_createSpecFileTemplate
    specfile_path = "#{request.path}/#{params[:package]}.spec"
    begin
      backend_get( specfile_path )
      render_error :status => 400, :errorcode => 'spec_file_exists',
        :message => 'SPEC file already exists.'
      return
    rescue ActiveXML::Transport::NotFoundError
      specfile = File.read "#{Rails.root}/files/specfiletemplate"
      Suse::Backend.put( specfile_path, specfile )
    end
    render_ok
  end

  # OBS 3.0: this should be obsoleted, we have /build/ controller for this
  # POST /source/<project>/<package>?cmd=rebuild
  def package_command_rebuild
    repo_name = params[:repo]
    arch_name = params[:arch]

    # check for sources in this or linked project
    unless @package
      # check if this is a package on a remote OBS instance
      answer = Suse::Backend.get(request.path)
      unless answer
        render_error :status => 400, :errorcode => 'unknown_package',
          :message => "Unknown package '#{package_name}'"
        return
      end
    end

    path = "/build/#{@project.name}?cmd=rebuild&package=#{@package.name}"
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

    backend.direct_http( URI(path), :method => 'POST', :data => '')

    render_ok
  end

  # POST /source/<project>/<package>?cmd=commit
  def package_command_commit

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment, :rev, :linkrev, :keeplink, :repairlink])
    pass_to_backend path

    if @package # except in case of _project package
      @package.sources_changed
    end
  end

  # POST /source/<project>/<package>?cmd=commitfilelist
  def package_command_commitfilelist

    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment, :rev, :linkrev, :keeplink, :repairlink])
    answer = pass_to_backend path

    if @package # except in case of _project package
      @package.sources_changed(answer)
    end
  end

  # POST /source/<project>/<package>?cmd=diff
  def package_command_diff
    #oproject_name = params[:oproject]
    #opackage_name = params[:opackage]

    path = request.path
    path << build_query_from_hash(params, [:cmd, :rev, :orev, :oproject, :opackage, :expand ,:linkrev, :olinkrev,
                                           :unified ,:missingok, :meta, :file, :filelimit, :tarlimit,
                                           :view, :withissues, :onlyissues])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=linkdiff
  def package_command_linkdiff
    path = request.path
    path << build_query_from_hash(params, [:cmd, :rev, :unified, :linkrev, :file, :filelimit, :tarlimit,
                                           :view, :withissues, :onlyissues])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=servicediff
  def package_command_servicediff
    path = request.path
    path << build_query_from_hash(params, [:cmd, :rev, :unified, :file, :filelimit, :tarlimit, :view, :withissues, :onlyissues])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=copy
  def package_command_copy

    verify_can_modify_target!

    if @spkg
      # use real source in case we followed project link
      sproject = params[:oproject] = @spkg.project.name
      spackage = params[:opackage] = @spkg.name
    else
      sproject = params[:oproject] || params[:project]
      spackage = params[:opackage] || params[:package]
    end

    # create target package, if it does not exist
    reparse_backend_package(spackage, sproject) unless @package

    # We need to use the project name of package object, since it might come via a project linked project
    path = @package.source_path
    path << build_query_from_hash(params, [:cmd, :rev, :user, :comment, :oproject, :opackage, :orev, :expand,
                                           :keeplink, :repairlink, :linkrev, :olinkrev, :requestid,
                                           :noservice, :dontupdatesource, :withhistory])
    pass_to_backend path

    @package.sources_changed
  end

  def reparse_backend_package(spackage, sproject)
    answer = Suse::Backend.get("/source/#{CGI.escape(sproject)}/#{CGI.escape(spackage)}/_meta")
    if answer
      Package.transaction do
        adata = Xmlhash.parse(answer.body)
        adata['name'] = params[:package]
        p = @project.packages.new(name: params[:package])
        p.update_from_xml(adata)
        p.remove_all_persons
        p.remove_all_groups
        p.develpackage = nil
        p.store
      end
      @package = Package.find_by_project_and_name(params[:project], params[:package])
    else
      raise UnknownPackage.new "Unknown package #{spackage} in project #{sproject}"
    end
  end

  # POST /source/<project>/<package>?cmd=release
  def package_command_release

    pkg = Package.get_by_project_and_name params[:project], params[:package], use_source: true, follow_project_links: false

    # specified target
    if params[:target_project]
      # we do not create it ourself
      Project.get_by_name(params[:target_project])
      _package_command_release_manual_target(pkg)
    else
      spkg = Package.get_by_project_and_name(params[:project], params[:package])
      verify_repos_match!(spkg.project)

      # loop via all defined targets
      pkg.project.repositories.each do |repo|
        next if params[:repository] and params[:repository] != repo.name
        repo.release_targets.each do |releasetarget|
          # find md5sum and release source and binaries
          release_package(pkg, releasetarget.target_repository, pkg.name, repo, nil, params[:setrelease], true)
        end
      end
    end

    render_ok
  end

  def _package_command_release_manual_target(pkg)
      verify_can_modify_target!

      if params[:target_repository].blank? or params[:repository].blank?
        raise MissingParameterError.new 'release action with specified target project needs also "repository" and "target_repository" parameter'
      end
      targetrepo=Repository.find_by_project_and_repo_name(@target_project_name, params[:target_repository])
      raise UnknownRepository.new "Repository does not exist #{params[:target_repository]}" unless targetrepo

      repo=pkg.project.repositories.where(name: params[:repository])
      raise UnknownRepository.new "Repository does not exist #{params[:repository]}" unless repo.count > 0
      repo=repo.first

      release_package(pkg, targetrepo, pkg.name, repo, nil, params[:setrelease], true,)
  end
  private  :_package_command_release_manual_target

  # POST /source/<project>/<package>?cmd=runservice
  def package_command_runservice

    path = request.path
    path << build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend path

    @package.sources_changed
  end

  # POST /source/<project>/<package>?cmd=deleteuploadrev
  def package_command_deleteuploadrev

    path = request.path
    path << build_query_from_hash(params, [:cmd])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=linktobranch
  def package_command_linktobranch
    pkg_rev = params[:rev]
    pkg_linkrev = params[:linkrev]

    #convert link to branch
    rev = ''
    if not pkg_rev.nil? and not pkg_rev.empty?
      rev = "&orev=#{pkg_rev}"
    end
    linkrev = ''
    if not pkg_linkrev.nil? and not pkg_linkrev.empty?
      linkrev = "&linkrev=#{pkg_linkrev}"
    end
    Suse::Backend.post "/source/#{@package.project.name}/#{@package.name}?cmd=linktobranch&user=#{CGI.escape(params[:user])}#{rev}#{linkrev}", nil

    @package.sources_changed
    render_ok
  end

  def verify_can_modify_target!
    # we require a target, but are we allowed to modify the existing target ?
    if Project.exists_by_name(@target_project_name)
      @project = Project.get_by_name(@target_project_name)
    else
      return if User.current.can_create_project?(@target_project_name)
      raise CreateProjectNoPermission.new "no permission to create project #{@target_project_name}"
    end

    if Package.exists_by_project_and_name(@target_project_name, @target_package_name, follow_project_links: false)
      verify_can_modify_target_package!
    elsif !User.current.can_create_package_in?(@project)
      raise CmdExecutionNoPermission.new "no permission to create package in project #{@target_project_name}"
    end
  end

  def private_branch_command
    ret = BranchPackage.new(params).branch
    if ret[:text]
      render ret
    else
      Event::BranchCommand.create project: params[:project], package: params[:package],
                                  targetproject: params[:target_project], targetpackage: params[:target_package],
                                  user: User.current.login
      render_ok ret
    end
  end

  # POST /source/<project>/<package>?cmd=branch&target_project="optional_project"&target_package="optional_package"&update_project_attribute="alternative_attribute"&comment="message"
  def package_command_branch
    # find out about source and target dependening on command   - FIXME: ugly! sync calls

    # The branch command may be used just for simulation
    if !params[:dryrun] && @target_project_name
      verify_can_modify_target! unless params[:dryrun]
    end

    private_branch_command
  end

  # POST /source/<project>/<package>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def package_command_set_flag
    required_parameters :flag, :status

    obj_set_flag(@package)
  end

  # POST /source/<project>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def project_command_set_flag
    required_parameters :flag, :status

    # Raising permissions afterwards is not secure. Do not allow this by default.
    unless User.current.is_admin?
      if params[:flag] == 'access' and params[:status] == 'enable' and not @project.enabled_for?('access', params[:repository], params[:arch])
        raise Project::ForbiddenError.new
      end
      if params[:flag] == 'sourceaccess' and params[:status] == 'enable' and
          !@project.enabled_for?('sourceaccess', params[:repository], params[:arch])
        raise Project::ForbiddenError.new
      end
    end

    obj_set_flag(@project)
  end

  class InvalidFlag < APIException; end

  def obj_set_flag(obj)
    obj.transaction do
      begin
        # first remove former flags of the same class
        obj.remove_flag(params[:flag], params[:repository], params[:arch])
        obj.add_flag(params[:flag], params[:status], params[:repository], params[:arch])
      rescue ArgumentError => e
        raise InvalidFlag.new e.message
      end

      obj.store
    end
    render_ok
  end

  # POST /source/<project>/<package>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def package_command_remove_flag
    required_parameters :flag
    obj_remove_flag @package
  end

  # POST /source/<project>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def project_command_remove_flag
    required_parameters :flag
    obj_remove_flag @project
  end

  def obj_remove_flag(obj)
    obj.transaction do
      obj.remove_flag(params[:flag], params[:repository], params[:arch])
      obj.store
    end
    render_ok
  end

end
