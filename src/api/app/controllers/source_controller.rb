include MaintenanceHelper
include ValidationHelper

require 'builder/xchar'

class SourceController < ApplicationController
  class IllegalRequest < APIException
    setup 404, 'Illegal request'
  end

  validate_action index: { method: :get, response: :directory }
  validate_action projectlist: { method: :get, response: :directory }
  validate_action packagelist: { method: :get, response: :directory }
  validate_action filelist: { method: :get, response: :directory }
  validate_action show_project_meta: { response: :project }
  validate_action package_meta: { method: :get, response: :package }

  validate_action update_project_meta: { request: :project, response: :status }
  validate_action update_package_meta: { request: :package, response: :status }

  skip_before_action :extract_user, only: [:lastevents_public, :global_command_orderkiwirepos]
  skip_before_action :require_login, only: [:lastevents_public, :global_command_orderkiwirepos]

  before_action :require_valid_project_name, except: [:index, :lastevents, :lastevents_public,
                                                      :global_command_orderkiwirepos, :global_command_branch,
                                                      :global_command_createmaintenanceincident]

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

    if params.key? :deleted
      raise NoPermissionForDeleted unless admin_user
      pass_to_backend
    else
      projectlist
    end
  end

  def projectlist
    # list all projects (visible to user)
    output = Rails.cache.fetch(['projectlist', Project.maximum(:updated_at), Relationship.forbidden_project_ids]) do
      dir = Project.pluck(:name).sort
      output = ''
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
    if params.key? :deleted
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
    raise Project::UnknownObjectError, project_name unless @project
    # we let the backend list the packages after we verified the project is visible
    if params.key? :view
      if params[:view] == 'verboseproductlist'
        @products = Product.all_products(@project, params[:expand])
        render 'source/verboseproductlist', formats: [:xml]
        return
      elsif params[:view] == 'productlist'
        @products = Product.all_products(@project, params[:expand])
        render 'source/productlist', formats: [:xml]
        return
      elsif params[:view] == 'issues'
        render_project_issues
      else
        pass_to_backend
      end
      return
    end
    render_project_packages
  end

  def render_project_packages
    packages = params.key?(:expand) ? @project.expand_all_packages : @project.packages.pluck(:name)
    render 'source/project_pages', formats: [:xml],
            locals: { packages: packages, expand: params.key?(:expand) }
  end

  # DELETE /source/:project
  def delete_project
    project = Project.get_by_name(params[:project])

    # checks
    unless project.is_a?(Project) && User.current.can_modify_project?(project)
      logger.debug "No permission to delete project #{project}"
      render_error status: 403, errorcode: 'delete_project_no_permission',
                   message: "Permission denied (delete project #{project})"
      return
    end
    project.check_weak_dependencies!
    opts = { no_write_to_backend: true,
             force:               params[:force].present?,
             recursive_remove:    params[:remove_linking_repositories].present? }
    check_and_remove_repositories!(project.repositories, opts)

    logger.info "destroying project object #{project.name}"
    project.commit_opts = { comment: params[:comment] }
    begin
      project.destroy
    rescue ActiveRecord::RecordNotDestroyed => invalid
      exception_message = "Destroying Project #{project.name} failed: #{invalid.record.errors.full_messages.to_sentence}"
      logger.debug exception_message
      raise ActiveRecord::RecordNotDestroyed, exception_message
    end

    render_ok
  end

  # POST /source/:project?cmd
  #-----------------
  def project_command
    # init and validation
    #--------------------
    valid_commands = ['undelete', 'showlinked', 'remove_flag', 'set_flag', 'createpatchinfo',
                      'createkey', 'extendkey', 'copy', 'createmaintenanceincident', 'lock',
                      'unlock', 'release', 'addchannels', 'modifychannels', 'move', 'freezelink']

    if params[:cmd] && !params[:cmd].in?(valid_commands)
      raise IllegalRequest, 'invalid_command'
    end

    command = params[:cmd]
    project_name = params[:project]
    params[:user] = User.current.login

    if command.in?(['undelete', 'release', 'copy', 'move'])
      return dispatch_command(:project_command, command)
    end

    @project = Project.get_by_name(project_name)

    # unlock
    if command == 'unlock' && User.current.can_modify_project?(@project, true)
      dispatch_command(:project_command, command)
    elsif command == 'showlinked' || User.current.can_modify_project?(@project)
      # command: showlinked, set_flag, remove_flag, ...?
      dispatch_command(:project_command, command)
    else
      raise CmdExecutionNoPermission, "no permission to execute command '#{command}'"
    end
  end

  class NoLocalPackage < APIException; end
  class CmdExecutionNoPermission < APIException
    setup 403
  end

  def show_package_issues
    unless @tpkg
      raise NoLocalPackage, 'Issues can only be shown for local packages'
    end
    set_issues_default
    @tpkg.update_if_dirty
    render partial: 'package_issues'
  end

  before_action :require_package, only: [:show_package, :delete_package, :package_command]

  # GET /source/:project/:package
  def show_package
    if @deleted_package
      tpkg = Package.find_by_project_and_name(@target_project_name, @target_package_name)
      raise PackageExists, 'the package is not deleted' if tpkg

      validate_read_access_of_deleted_package(@target_project_name, @target_package_name)
    elsif ['_project', '_pattern'].include? @target_package_name
      Project.get_by_name @target_project_name
    else
      @tpkg = Package.get_by_project_and_name(@target_project_name, @target_package_name, use_source: true, follow_project_links: true)
    end

    show_package_issues && return if params[:view] == 'issues'

    # exec
    path = request.path_info
    path += build_query_from_hash(params, [:rev, :linkrev, :emptylink,
                                           :expand, :view, :extension,
                                           :lastworking, :withlinked, :meta,
                                           :deleted, :parse, :arch,
                                           :repository, :product, :nofilename])
    pass_to_backend path
  end

  class DeletePackageNoPermission < APIException
    setup 403
  end

  class ProjectExists < APIException
  end

  class PackageExists < APIException
  end

  def delete_package
    # checks
    if @target_package_name == '_project'
      raise DeletePackageNoPermission, '_project package can not be deleted.'
    end

    tpkg = Package.get_by_project_and_name(@target_project_name, @target_package_name,
                                           use_source: false, follow_project_links: false)

    unless User.current.can_modify_package?(tpkg)
      raise DeletePackageNoPermission, "no permission to delete package #{@target_package_name} in project #{@target_project_name}"
    end

    # deny deleting if other packages use this as develpackage
    tpkg.check_weak_dependencies! unless params[:force]

    logger.info "destroying package object #{tpkg.name}"
    tpkg.commit_opts = { comment: params[:comment] }

    begin
      tpkg.destroy
    rescue ActiveRecord::RecordNotDestroyed => invalid
      exception_message = "Destroying Package #{tpkg.project.name}/#{tpkg.name} failed: #{invalid.record.errors.full_messages.to_sentence}"
      logger.debug exception_message
      raise ActiveRecord::RecordNotDestroyed, exception_message
    end

    render_ok
  end

  # before_action for show_package, delete_package and package_command
  def require_package
    # init and validation
    #--------------------
    # admin_user = User.current.is_admin?
    @deleted_package = params.key? :deleted

    # FIXME: for OBS 3, api of branch and copy calls have target and source in the opossite place
    if params[:cmd].in?(['branch', 'release'])
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
    return if User.current.can_modify_package?(@package)

    unless @package.class == Package
      raise CmdExecutionNoPermission, "no permission to execute command '#{params[:cmd]}' " \
                                      'for unspecified package'
    end
    raise CmdExecutionNoPermission, "no permission to execute command '#{params[:cmd]}' " \
                                    "for package #{@package.name} in project #{@package.project.name}"
  end

  # POST /source/:project/:package
  def package_command
    params[:user] = User.current.login

    unless params[:cmd]
      raise MissingParameterError, 'POST request without given cmd parameter'
    end

    # valid post commands
    valid_commands = ['diff', 'branch', 'servicediff', 'linkdiff', 'showlinked', 'copy',
                      'remove_flag', 'set_flag', 'undelete', 'runservice', 'waitservice',
                      'mergeservice', 'commit', 'commitfilelist', 'createSpecFileTemplate',
                      'deleteuploadrev', 'linktobranch', 'updatepatchinfo', 'getprojectservices',
                      'unlock', 'release', 'importchannel', 'wipe', 'rebuild', 'collectbuildenv',
                      'instantiate', 'addchannels', 'enablechannel']

    @command = params[:cmd]
    raise IllegalRequest, 'invalid_command' unless valid_commands.include?(@command)

    if params[:oproject]
      origin_project_name = params[:oproject]
      valid_project_name! origin_project_name
    end
    if params[:opackage]
      origin_package_name = params[:opackage]
      valid_package_name! origin_package_name
    end

    required_parameters :oproject if origin_package_name

    valid_project_name! params[:target_project] if params[:target_project]
    valid_package_name! params[:target_package] if params[:target_package]

    # Check for existence/access of origin package when specified
    @spkg = nil
    Project.get_by_name origin_project_name if origin_project_name
    if origin_package_name && !origin_package_name.in?(['_project', '_pattern']) && !(params[:missingok] && @command.in?(['branch', 'release']))
      @spkg = Package.get_by_project_and_name(origin_project_name, origin_package_name)
    end
    unless PACKAGE_CREATING_COMMANDS.include?(@command) && !Project.exists_by_name(@target_project_name)
      valid_project_name! params[:project]
      if @command == 'release' # wipe and rebuild should become supported as well
        valid_multibuild_package_name!(params[:package])
      else
        valid_package_name!(params[:package])
      end
      # even when we can create the package, an existing instance must be checked if permissions are right
      @project = Project.get_by_name @target_project_name
      # rubocop:disable Metrics/LineLength
      if !PACKAGE_CREATING_COMMANDS.include?(@command) || Package.exists_by_project_and_name(@target_project_name,
                                                                                             @target_package_name,
                                                                                             follow_project_links: SOURCE_UNTOUCHED_COMMANDS.include?(@command))
        validate_target_for_package_command_exists!
      end
      # rubocop:enable Metrics/LineLength
    end

    dispatch_command(:package_command, @command)
  end

  SOURCE_UNTOUCHED_COMMANDS = ['branch', 'diff', 'linkdiff', 'servicediff', 'showlinked', 'rebuild', 'wipe',
                               'waitservice', 'remove_flag', 'set_flag', 'getprojectservices'].freeze
  # list of cammands which create the target package
  PACKAGE_CREATING_COMMANDS = ['branch', 'release', 'copy', 'undelete', 'instantiate'].freeze
  # list of commands which are allowed even when the project has the package only via a project link
  READ_COMMANDS = ['branch', 'diff', 'linkdiff', 'servicediff', 'showlinked', 'getprojectservices', 'release'].freeze

  def validate_target_for_package_command_exists!
    @project = nil
    @package = nil

    follow_project_links = SOURCE_UNTOUCHED_COMMANDS.include?(@command)

    unless @target_package_name.in?(['_project', '_pattern'])
      use_source = true
      use_source = false if @command == 'showlinked'
      @package = Package.get_by_project_and_name(@target_project_name, @target_package_name,
                                                 use_source: use_source, follow_project_links: follow_project_links)
      if @package # for remote package case it's nil
        @project = @package.project
        ignore_lock = @command == 'unlock'
        unless READ_COMMANDS.include?(@command) || User.current.can_modify_package?(@package, ignore_lock)
          raise CmdExecutionNoPermission, "no permission to modify package #{@package.name} in project #{@project.name}"
        end
      end
    end

    # check read access rights when the package does not exist anymore
    validate_read_access_of_deleted_package(@target_project_name, @target_package_name) if @package.nil? && @deleted_package
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
      raise InvalidProjectParameters if params[:view]
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
    project_name = params[:project]
    params[:user] = User.current.login

    request_data = Xmlhash.parse(request.raw_post)

    # permission check
    if request_data['name'] != project_name
      raise ProjectNameMismatch, "project name in xml data ('#{request_data['name']}) does not match resource path component ('#{project_name}')"
    end

    begin
      project = Project.get_by_name(request_data['name'])
    rescue Project::UnknownObjectError
      project = nil
    end

    # Need permission
    logger.debug 'Checking permission for the put'
    if project
      # project exists, change it
      unless User.current.can_modify_project?(project)
        if project.is_locked?
          logger.debug "no permission to modify LOCKED project #{project.name}"
          raise ChangeProjectNoPermission, "The project #{project.name} is locked"
        end
        logger.debug "user #{user.login} has no permission to modify project #{project.name}"
        raise ChangeProjectNoPermission, 'no permission to change project'
      end
    else
      # project is new
      unless User.current.can_create_project?(project_name)
        logger.debug 'Not allowed to create new project'
        raise CreateProjectNoPermission, "no permission to create project #{project_name}"
      end
    end

    # projects using remote resources must be edited by the admin
    result = Project.validate_remote_permissions(request_data)
    if result[:error]
      raise ChangeProjectNoPermission, 'admin rights are required to change projects using remote resources'
    end

    result = Project.validate_link_xml_attribute(request_data, project_name)
    raise ProjectReadAccessFailure, result[:error] if result[:error]

    result = Project.validate_maintenance_xml_attribute(request_data)
    raise ModifyProjectNoPermission, result[:error] if result[:error]

    result = Project.validate_repository_xml_attribute(request_data, project_name)
    raise RepositoryAccessFailure, result[:error] if result[:error]

    if project
      remove_repositories = project.get_removed_repositories(request_data)
      opts = { no_write_to_backend: true,
               force:               params[:force].present?,
               recursive_remove:    params[:remove_linking_repositories].present? }
      check_and_remove_repositories!(remove_repositories, opts)
    end

    Project.transaction do
      # exec
      if project
        project.update_from_xml!(request_data)
      else
        project = Project.new(name: project_name)
        project.update_from_xml!(request_data)
        # FIXME3.0: don't modify send data
        project.relationships.build(user: User.current, role: Role.find_by_title!('maintainer'))
      end
      project.store(comment: params[:comment])
    end
    render_ok
  end

  def check_and_remove_repositories!(repositories, opts)
    result = Project.check_repositories(repositories) unless opts[:force]
    raise RepoDependency, result[:error] if !opts[:force] && result[:error]

    result = Project.remove_repositories(repositories, opts)
    raise ChangeProjectNoPermission, result[:error] if !opts[:force] && result[:error]
  end

  # GET /source/:project/_config
  def show_project_config
    begin
      # 'project' can be a local Project in database or a String that's the name of a remote project, or even raise exceptions
      project = Project.get_by_name(params[:project])
    rescue Project::ReadAccessError, Project::UnknownObjectError => e
      render_error status: 404, message: e.message
      return
    end
    config = project.is_a?(String) ? ProjectConfigFile.new(project_name: project) : project.config

    sliced_params = params.slice(:rev)
    sliced_params.permit!

    return if forward_from_backend(config.full_path(sliced_params.to_h))

    content = config.to_s(sliced_params.to_h)
    unless content
      render_error status: 404, message: config.errors.full_messages.to_sentence
      return
    end

    send_data(content, type: config.response[:type], disposition: 'inline')
  end

  class PutProjectConfigNoPermission < APIException
    setup 403
  end

  # PUT /source/:project/_config
  def update_project_config
    project = Project.get_by_name(params[:project])

    if project.is_a?(String)
      raise PutProjectConfigNoPermission, 'Can\'t write on an remote instance'
    end

    unless User.current.can_modify_project?(project)
      raise PutProjectConfigNoPermission, "No permission to write build configuration for project '#{params[:project]}'"
    end

    params[:user] = User.current.login
    project.config.file = request.body

    sliced_params = params.slice(:user, :comment)
    sliced_params.permit!

    response = project.config.save(sliced_params.to_h)

    unless response
      render_error status: 404, message: project.config.errors.full_messages.to_sentence
      return
    end

    send_data(response.body,
              type: response.fetch('content-type'),
              disposition: 'inline')
  end

  def pubkey_path
    # check for project
    @prj = Project.get_by_name(params[:project])
    request.path_info + build_query_from_hash(params, [:user, :comment, :meta, :rev])
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

    # check for permissions
    upper_project = @prj.name.gsub(/:[^:]*$/, '')
    while upper_project != @prj.name && upper_project.present?
      if Project.exists_by_name(upper_project) && User.current.can_modify_project?(Project.get_by_name(upper_project))
        pass_to_backend path
        return
      end
      break unless upper_project.include? ':'
      upper_project = upper_project.gsub(/:[^:]*$/, '')
    end

    if User.current.is_admin?
      pass_to_backend path
    else
      raise DeleteProjectPubkeyNoPermission, "No permission to delete public key for project '#{params[:project]}'. " \
                                             'Either maintainer permissions by upper project or admin permissions is needed.'
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

    if params.key?(:meta) || params.key?(:rev) || params.key?(:view) || pack.nil?
      # check if this comes from a remote project, also true for _project package
      # or if meta is specified we need to fetch the meta from the backend
      path = request.path_info
      path += build_query_from_hash(params, [:meta, :rev, :view])
      pass_to_backend path
      return
    end

    render xml: pack.to_axml
  end

  # PUT /source/:project/:package/_meta
  def update_package_meta
    require_package_name

    rdata = Xmlhash.parse(request.raw_post)

    if rdata['project'] && rdata['project'] != @project_name
      render_error status: 400, errorcode: 'project_name_mismatch',
                   message: 'project name in xml data does not match resource path component'
      return
    end

    if rdata['name'] && rdata['name'] != @package_name
      render_error status: 400, errorcode: 'package_name_mismatch',
                   message: 'package name in xml data does not match resource path component'
      return
    end

    # check for project
    if Package.exists_by_project_and_name(@project_name, @package_name, follow_project_links: false)
      pkg = Package.get_by_project_and_name(@project_name, @package_name, use_source: false)
      unless User.current.can_modify_package?(pkg)
        render_error status: 403, errorcode: 'change_package_no_permission',
                     message: "no permission to modify package '#{pkg.project.name}'/#{pkg.name}"
        return
      end

      if pkg && !pkg.disabled_for?('sourceaccess', nil, nil)
        if FlagHelper.xml_disabled_for?(rdata, 'sourceaccess') && !User.current.is_admin?
          render_error status: 403, errorcode: 'change_package_protection_level',
                       message: 'admin rights are required to raise the protection level of a package'
          return
        end
      end
    else
      prj = Project.get_by_name(@project_name)
      unless prj.is_a?(Project) && User.current.can_create_package_in?(prj)
        render_error status: 403, errorcode: 'create_package_no_permission',
                     message: "no permission to create a package in project '#{@project_name}'"
        return
      end
      pkg = prj.packages.new(name: @package_name)
    end

    pkg.set_comment(params[:comment])
    pkg.update_from_xml(rdata)
    render_ok
  end

  # GET /source/:project/:package/:filename
  def get_file
    project_name = params[:project]
    package_name = params[:package] || '_project'
    file = params[:filename]

    if params.key?(:deleted)
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
      pack = Package.get_by_project_and_name(project_name, package_name, use_source: true)
      if pack
        # in case of project links, we need to rewrite the target
        project_name = pack.project.name
        package_name = pack.name
      end
    end

    path = Package.source_path(project_name, package_name, file)
    path += build_query_from_hash(params, [:rev, :meta, :deleted, :limit, :expand, :view])
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

    # authenticate
    params[:user] = User.current.login

    @prj = Project.get_by_name(@project_name)
    @pack = nil
    @allowed = false

    if @package_name == '_project' || @package_name == '_pattern'
      @allowed = permissions.project_change? @prj

      if @file == '_attribute' && @package_name == '_project'
        raise WrongRouteForAttribute, "Attributes need to be changed through #{change_attribute_path(project: params[:project])}"
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
      raise PutFileNoPermission, "Insufficient permissions to store file in package #{@package_name}, project #{@project_name}"
    end

    # _pattern was not a real package in former OBS 2.0 and before, so we need to create the
    # package here implicit to stay api compatible.
    # FIXME3.0: to be revisited
    if @package_name == '_pattern' && !Package.exists_by_project_and_name(@project_name, @package_name, follow_project_links: false)
      @pack = Package.new(name: '_pattern', title: 'Patterns', description: 'Package Patterns')
      @prj.packages << @pack
      @pack.save
    end

    Package.verify_file!(@pack, params[:filename], request.raw_post.to_s)

    @path += build_query_from_hash(params, [:user, :comment, :rev, :linkrev, :keeplink, :meta])
    pass_to_backend @path

    # update package timestamp and reindex sources
    return if params[:rev] == 'repository' || @package_name.in?(['_project', '_pattern'])
    special_file = params[:filename].in?(['_aggregate', '_constraints', '_link', '_service', '_patchinfo', '_channel'])
    @pack.sources_changed(wait_for_update: special_file) # wait for indexing for special files
  end

  # DELETE /source/:project/:package/:filename
  def delete_file
    check_permissions_for_file

    unless @allowed
      raise DeleteFileNoPermission, 'Insufficient permissions to delete file'
    end

    @path += build_query_from_hash(params, [:user, :comment, :meta, :rev, :linkrev, :keeplink])
    Backend::Connection.delete @path

    unless @package_name == '_pattern' || @package_name == '_project'
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
    volley_backend_path(path) unless forward_from_backend(path)
  end

  # POST /source?cmd=createmaintenanceincident
  def global_command_createmaintenanceincident
    # set defaults
    at = nil
    unless params[:attribute]
      params[:attribute] = 'OBS:MaintenanceProject'
      at = AttribType.find_by_name!(params[:attribute])
    end

    # find maintenance project via attribute
    prj = Project.get_maintenance_project(at)
    actually_create_incident(prj)
  end

  # POST /source?cmd=branch (aka osc mbranch)
  def global_command_branch
    private_branch_command
  end

  # POST /source?cmd=orderkiwirepos
  def global_command_orderkiwirepos
    pass_to_backend
  end

  private

  class AttributeNotFound < APIException
    setup 'not_found', 404
  end

  class ModifyProjectNoPermission < APIException
    setup 403
  end

  def actually_create_incident(project)
    unless User.current.can_modify_project?(project)
      raise ModifyProjectNoPermission, "no permission to modify project '#{project.name}'"
    end

    incident = MaintenanceIncident.build_maintenance_incident(project, params[:noaccess].present?)

    if incident
      render_ok data: { targetproject: incident.project.name }
    else
      render_error status: 400, errorcode: 'incident_has_no_maintenance_project',
                   message: 'incident projects shall only create below maintenance projects'
    end
  end

  class RepoDependency < APIException
  end

  # create a id collection of all projects doing a project link to this one
  # POST /source/<project>?cmd=showlinked
  def project_command_showlinked
    builder = Builder::XmlMarkup.new(indent: 2)
    xml = builder.collection do |c|
      @project.linked_by_projects.each do |l|
        p = {}
        p[:name] = l.name
        c.project(p)
      end
    end
    render xml: xml
  end

  # lock a project
  # POST /source/<project>?cmd=lock
  def project_command_lock
    # comment is optional

    @project.lock(params[:comment])

    render_ok
  end

  # unlock a project
  # POST /source/<project>?cmd=unlock
  def project_command_unlock
    required_parameters :comment

    @project.unlock!(params[:comment])

    render_ok
  end

  # freeze project link, either creating the freeze or updating it
  # POST /source/<project>?cmd=freezelink
  def project_command_freezelink
    pass_to_backend(request.path_info + build_query_from_hash(params, [:cmd, :user, :comment]))
  end

  # add channel packages and extend repository list
  # POST /source/<project>?cmd=addchannels
  def project_command_addchannels
    mode = case params[:mode]
           when 'skip_disabled'
             :skip_disabled
           when 'enable_all'
             :enable_all
           else
             :add_disabled
    end

    @project.packages.each do |pkg|
      pkg.add_channels(mode)
    end

    render_ok
  end

  # add repositories and/or enable them for all existing channel instances
  # POST /source/<project>?cmd=modifychannels
  def project_command_modifychannels
    mode = nil
    mode = :add_disabled  if params[:mode] == 'add_disabled'
    mode = :enable_all    if params[:mode] == 'enable_all'

    @project.packages.each do |pkg|
      pkg.modify_channel(mode)
    end
    @project.store(user: User.current.login)

    render_ok
  end

  def private_plain_backend_command
    # is there any value in this call?
    Project.find_by_name params[:project]

    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :user, :comment])
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
      raise CmdExecutionNoPermission, "no permission to execute command 'undelete'"
    end

    Project.restore(params[:project])
  end

  # POST /source/<project>?cmd=release
  def project_command_release
    params[:user] = User.current.login

    @project = Project.get_by_name params[:project], includeallpackages: 1
    verify_repos_match!(@project)

    if @project.is_a? String # remote project
      render_error status: 404, errorcode: 'remote_project',
        message: 'The release from remote projects is currently not supported'
      return
    end

    if params.key? :nodelay
      @project.do_project_release(params)
      render_ok
    else
      # inject as job
      ProjectDoProjectReleaseJob.perform_later(
        @project.id,
        params.slice(:project, :targetproject, :targetreposiory, :repository, :setrelease, :user).permit!.to_h
      )
      render_invoked
    end
  end

  def verify_repos_match!(pro)
    repo_matches = nil
    pro.repositories.each do |repo|
      next if params[:repository] && params[:repository] != repo.name
      repo.release_targets.each do |releasetarget|
        unless User.current.can_modify_project?(releasetarget.target_repository.project)
          raise CmdExecutionNoPermission, "no permission to write in project #{releasetarget.target_repository.project.name}"
        end
        unless releasetarget.trigger == 'manual'
          raise CmdExecutionNoPermission, 'Trigger is not set to manual in repository' \
                                          " #{releasetarget.repository.project.name}/#{releasetarget.repository.name}"
        end
        repo_matches = true
      end
    end
    raise NoMatchingReleaseTarget, 'No defined or matching release target' unless repo_matches
  end

  class RemoteProjectError < APIException
    setup 'remote_project', 404
  end
  class ProjectCopyNoPermission < APIException
    setup 403
  end

  # POST /source/<project>?cmd=move&oproject=<project>
  def project_command_move
    unless User.current.is_admin?
      raise CmdExecutionNoPermission, 'Admin permissions required. STOP SCHEDULER BEFORE.'
    end
    if Project.exists_by_name(params[:project])
      raise ProjectExists, 'Target project exists already.'
    end

    begin
      project = Project.get_by_name(params[:oproject])
      commit = { login:   User.current.login,
                 lowprio: 1,
                 comment: "Project move from #{params[:oproject]} to #{params[:project]}" }
      commit[:comment] = params[:comment] if params[:comment].present?
      Backend::Api::Sources::Project.move(params[:oproject], params[:project])
      project.name = params[:project]
      project.store(commit)
      # update meta data in all packages, they contain the project name as well
      project.packages.each { |package| package.store(commit) }
    rescue
      render_error status: 400, errorcode: 'move_failed',
        message: 'Move operation failed'
      return
    end

    project.all_sources_changed
    project.linked_by_projects.each(&:all_sources_changed)

    render_ok
  end

  # POST /source/<project>?cmd=copy
  def project_command_copy
    project_name = params[:project]

    @project = Project.find_by_name(project_name)
    unless (@project && User.current.can_modify_project?(@project)) || User.current.can_create_project?(project_name)
      raise CmdExecutionNoPermission, "no permission to execute command 'copy'"
    end
    oprj = Project.get_by_name(params[:oproject], includeallpackages: 1)
    if params.key?(:makeolder) || params.key?(:makeoriginolder)
      unless User.current.can_modify_project?(oprj)
        raise CmdExecutionNoPermission, "no permission to execute command 'copy', requires modification permission in origin project"
      end
    end

    if oprj.is_a? String # remote project
      raise RemoteProjectError, 'The copy from remote projects is currently not supported'
    end

    unless User.current.is_admin?
      if params[:withbinaries]
        raise ProjectCopyNoPermission, 'no permission to copy project with binaries for non admins'
      end

      unless oprj.is_a? String
        oprj.packages.each do |pkg|
          next unless pkg.disabled_for?('sourceaccess', nil, nil)
          raise ProjectCopyNoPermission, "no permission to copy project due to source protected package #{pkg.name}"
        end
      end
    end

    # create new project object based on oproject
    unless @project
      Project.transaction do
        if oprj.is_a? String # remote project
          rdata = Xmlhash.parse(Backend::Api::Sources::Project.meta(oprj))
          @project = Project.new name: project_name, title: rdata['title'], description: rdata['description']
        else # local project
          @project = Project.new name: project_name, title: oprj.title, description: oprj.description
          @project.save
          oprj.flags.each do |f|
            @project.flags.create(status: f.status, flag: f.flag, architecture: f.architecture, repo: f.repo) unless f.flag == 'lock'
          end
          oprj.repositories.each do |repo|
            r = @project.repositories.create name: repo.name
            repo.repository_architectures.each do |ra|
              r.repository_architectures.create! architecture: ra.architecture, position: ra.position
            end
            position = 0
            repo.path_elements.each do |pe|
              position += 1
              r.path_elements << PathElement.new(link: pe.link, position: position)
            end
          end
        end
        @project.store
      end
    end

    if params.key? :nodelay
      @project.do_project_copy(params)
      render_ok
    else
      job_params =
        params.slice(
          :cmd, :user, :comment, :oproject, :withbinaries, :withhistory, :makeolder, :makeoriginolder, :noservice
        ).permit!.to_h

      ProjectDoProjectCopyJob.perform_later(@project.id, job_params)
      render_invoked
    end
  end

  # POST /source/<project>?cmd=createpatchinfo
  def project_command_createpatchinfo
    # project_name = params[:project]
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
    repo = nil
    repo = Repository.find_by_project_and_name(params[:target_project], params[:target_repository]) if params[:target_project]

    import_channel(request.raw_post, @package, repo)

    render_ok
  end

  class NotLocked < APIException; end

  # unlock a package
  # POST /source/<project>/<package>?cmd=unlock
  def package_command_unlock
    required_parameters :comment

    p = { comment: params[:comment] }

    f = @package.flags.find_by_flag_and_status('lock', 'enable')
    raise NotLocked, "package '#{@package.project.name}/#{@package.name}' is not locked" unless f
    @package.flags.delete(f)
    @package.store(p)

    render_ok
  end

  # add channel packages and extend repository list
  # POST /source/<project>?cmd=addchannels
  def package_command_addchannels
    mode = :add_disabled
    mode = :skip_disabled if params[:mode] == 'skip_disabled'
    mode = :enable_all    if params[:mode] == 'enable_all'

    @package.add_channels(mode)

    render_ok
  end

  # add repositories and/or enable them for a specified channel
  # POST /source/<project>/<package>?cmd=enablechannel
  def package_command_enablechannel
    @package.modify_channel(:enable_all)
    @package.project.store(user: User.current.login)

    render_ok
  end

  # Collect all project source services for a package
  # POST /source/<project>/<package>?cmd=getprojectservices
  def package_command_getprojectservices
    path = request.path_info
    path += build_query_from_hash(params, [:cmd])
    pass_to_backend path
  end

  # create a id collection of all packages doing a package source link to this one
  # POST /source/<project>/<package>?cmd=showlinked
  def package_command_showlinked
    unless @package
      # package comes from remote instance or is hidden

      # FIXME: return an empty list for now
      # we could request the links on remote instance via that: but we would need to search also localy and merge ...

      # path = "/search/package/id?match=(@linkinfo/package=\"#{CGI.escape(package_name)}\"+and+@linkinfo/project=\"#{CGI.escape(project_name)}\")"
      # answer = Backend::Connection.post path
      # render :text => answer.body, :content_type => 'text/xml'
      render xml: '<collection/>'
      return
    end

    builder = Builder::XmlMarkup.new(indent: 2)
    xml = builder.collection do |c|
      @package.find_linking_packages.each do |l|
        p = {}
        p[:project] = l.project.name
        p[:name] = l.name
        c.package(p)
      end
    end
    render xml: xml
  end

  # POST /source/<project>/<package>?cmd=collectbuildenv
  def package_command_collectbuildenv
    required_parameters :oproject, :opackage

    Package.get_by_project_and_name(@target_project_name, @target_package_name)

    path = request.path_info
    path << build_query_from_hash(params, [:cmd, :user, :comment, :orev, :oproject, :opackage])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=instantiate
  def package_command_instantiate
    project = Project.get_by_name(params[:project])
    opackage = Package.get_by_project_and_name(project.name, params[:package], check_update_project: true)
    unless opackage
      raise RemoteProjectError, 'Instantiation from remote project is not supported'
    end
    if project == opackage.project
      raise CmdExecutionNoPermission, 'package is already intialized here'
    end
    unless User.current.can_modify_project?(project)
      raise CmdExecutionNoPermission, "no permission to execute command 'copy'"
    end
    unless User.current.can_modify_package?(opackage, true) # ignore_lock option
      raise CmdExecutionNoPermission, 'no permission to modify source package'
    end

    opts = {}
    at = AttribType.find_by_namespace_and_name!('OBS', 'MakeOriginOlder')
    opts[:makeoriginolder] = true if project.attribs.find_by(attrib_type: at) # object or nil
    opts[:makeoriginolder] = true if params[:makeoriginolder]
    instantiate_container(project, opackage.update_instance, opts)
    render_ok
  end

  # POST /source/<project>/<package>?cmd=undelete
  def package_command_undelete
    if Package.exists_by_project_and_name(@target_project_name, @target_package_name, follow_project_links: false)
      raise PackageExists, "the package exists already #{@target_project_name} #{@target_package_name}"
    end
    tprj = Project.get_by_name(@target_project_name)
    unless tprj.is_a?(Project) && User.current.can_create_package_in?(tprj)
      raise CmdExecutionNoPermission, "no permission to create package in project #{@target_project_name}"
    end

    path = request.path_info
    unless User.current.is_admin? || params[:time].blank?
      raise CmdExecutionNoPermission, 'Only administrators are allowed to set the time'
    end
    path += build_query_from_hash(params, [:cmd, :user, :comment, :time])
    pass_to_backend path

    # read meta data from backend to restore database object
    prj = Project.find_by_name!(params[:project])
    pkg = prj.packages.new(name: params[:package])
    pkg.update_from_xml(Xmlhash.parse(Backend::Api::Sources::Package.meta(params[:project], params[:package])))
    pkg.store
  end

  # FIXME: obsolete this for 3.0
  # POST /source/<project>/<package>?cmd=createSpecFileTemplate
  def package_command_createSpecFileTemplate
    begin
      # TODO: No need to read the whole file for knowing if it exists already
      Backend::Api::Sources::Package.file(params[:project], params[:package], "#{params[:package]}.spec")
      render_error status: 400, errorcode: 'spec_file_exists',
        message: 'SPEC file already exists.'
      return
    rescue ActiveXML::Transport::NotFoundError
      specfile_content = File.read("#{Rails.root}/files/specfiletemplate")
      Backend::Api::Sources::Package.write_file(params[:project], params[:package], "#{params[:package]}.spec", specfile_content)
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
      answer = Backend::Connection.get(request.path_info)
      unless answer
        render_error status: 400, errorcode: 'unknown_package',
          message: "Unknown package '#{package_name}'"
        return
      end
    end

    options = {}
    if repo_name
      if @package && @package.repositories.find_by_name(repo_name).nil?
        render_error status: 400, errorcode: 'unknown_repository',
          message: "Unknown repository '#{repo_name}'"
        return
      end
      options[:repository] = repo_name
    end
    options[:arch] = arch_name if arch_name

    Backend::Api::Sources::Package.rebuild(@project.name, @package.name, options)

    render_ok
  end

  # POST /source/<project>/<package>?cmd=commit
  def package_command_commit
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :user, :comment, :rev, :linkrev, :keeplink, :repairlink])
    pass_to_backend path

    @package.sources_changed if @package # except in case of _project package
  end

  # POST /source/<project>/<package>?cmd=commitfilelist
  def package_command_commitfilelist
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :user, :comment, :rev, :linkrev, :keeplink, :repairlink, :withvalidate])
    answer = pass_to_backend path

    @package.sources_changed(dir_xml: answer) if @package # except in case of _project package
  end

  # POST /source/<project>/<package>?cmd=diff
  def package_command_diff
    # oproject_name = params[:oproject]
    # opackage_name = params[:opackage]

    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :rev, :orev, :oproject, :opackage, :expand, :linkrev, :olinkrev,
                                           :unified, :missingok, :meta, :file, :filelimit, :tarlimit,
                                           :view, :withissues, :onlyissues])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=linkdiff
  def package_command_linkdiff
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :rev, :unified, :linkrev, :file, :filelimit, :tarlimit,
                                           :view, :withissues, :onlyissues])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=servicediff
  def package_command_servicediff
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :rev, :unified, :file, :filelimit, :tarlimit, :view, :withissues, :onlyissues])
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
                                           :withvrev, :noservice, :dontupdatesource, :withhistory])
    pass_to_backend path

    @package.sources_changed
  end

  def reparse_backend_package(spackage, sproject)
    answer = Backend::Api::Sources::Package.meta(sproject, spackage)
    raise UnknownPackage, "Unknown package #{spackage} in project #{sproject}" unless answer

    Package.transaction do
      adata = Xmlhash.parse(answer)
      adata['name'] = params[:package]
      p = @project.packages.new(name: params[:package])
      p.update_from_xml(adata)
      p.remove_all_persons
      p.remove_all_groups
      p.develpackage = nil
      p.store
    end
    @package = Package.find_by_project_and_name(params[:project], params[:package])
  end

  # POST /source/<project>/<package>?cmd=release
  def package_command_release
    pkg = Package.get_by_project_and_name params[:project], params[:package], use_source: true, follow_project_links: false, follow_multibuild: true
    multibuild_container = nil
    if params[:package].include?(':') && !params[:package].starts_with?('_product:')
      multibuild_container = params[:package].gsub(/^.*:/, '')
    end

    # specified target
    if params[:target_project]
      # we do not create it ourself
      Project.get_by_name(params[:target_project])
      _package_command_release_manual_target(pkg, multibuild_container)
    else
      verify_repos_match!(pkg.project)

      # loop via all defined targets
      pkg.project.repositories.each do |repo|
        next if params[:repository] && params[:repository] != repo.name
        repo.release_targets.each do |releasetarget|
          target_package_name = pkg.release_target_name
          # emulate a maintenance release request action here in case
          if pkg.project.is_maintenance_incident?
            # The maintenance ID is always the sub project name of the maintenance project
            target_package_name += '.' << pkg.project.name.gsub(/.*:/, '')
          end

          # find md5sum and release source and binaries
          release_package(pkg, releasetarget.target_repository, target_package_name, repo, multibuild_container, nil, params[:setrelease], true)
        end
      end
    end

    render_ok
  end

  def _package_command_release_manual_target(pkg, multibuild_container)
    verify_can_modify_target!

    if params[:target_repository].blank? || params[:repository].blank?
      raise MissingParameterError, 'release action with specified target project needs also "repository" and "target_repository" parameter'
    end
    targetrepo = Repository.find_by_project_and_name(@target_project_name, params[:target_repository])
    raise UnknownRepository, "Repository does not exist #{params[:target_repository]}" unless targetrepo

    repo = pkg.project.repositories.where(name: params[:repository])
    raise UnknownRepository, "Repository does not exist #{params[:repository]}" unless repo.count > 0
    repo = repo.first

    release_package(pkg, targetrepo, pkg.name, repo, multibuild_container, nil, params[:setrelease], true)
  end
  private :_package_command_release_manual_target

  # POST /source/<project>/<package>?cmd=waitservice
  def package_command_waitservice
    path = request.path_info
    path += build_query_from_hash(params, [:cmd])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=mergeservice
  def package_command_mergeservice
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend path

    @package.sources_changed
  end

  # POST /source/<project>/<package>?cmd=runservice
  def package_command_runservice
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend path

    @package.sources_changed
  end

  # POST /source/<project>/<package>?cmd=deleteuploadrev
  def package_command_deleteuploadrev
    path = request.path_info
    path += build_query_from_hash(params, [:cmd])
    pass_to_backend path
  end

  # POST /source/<project>/<package>?cmd=linktobranch
  def package_command_linktobranch
    pkg_rev = params[:rev]
    pkg_linkrev = params[:linkrev]

    # convert link to branch
    rev = ''
    rev = "&orev=#{pkg_rev}" if pkg_rev.present?
    linkrev = ''
    linkrev = "&linkrev=#{pkg_linkrev}" if pkg_linkrev.present?
    Backend::Connection.post "/source/#{@package.project.name}/#{@package.name}?cmd=linktobranch&user=#{CGI.escape(params[:user])}#{rev}#{linkrev}"

    @package.sources_changed
    render_ok
  end

  def verify_can_modify_target!
    # we require a target, but are we allowed to modify the existing target ?
    if Project.exists_by_name(@target_project_name)
      @project = Project.get_by_name(@target_project_name)
    else
      return if User.current.can_create_project?(@target_project_name)
      raise CreateProjectNoPermission, "no permission to create project #{@target_project_name}"
    end

    if Package.exists_by_project_and_name(@target_project_name, @target_package_name, follow_project_links: false)
      verify_can_modify_target_package!
    elsif !@project.is_a?(Project) || !User.current.can_create_package_in?(@project)
      raise CmdExecutionNoPermission, "no permission to create package in project #{@target_project_name}"
    end
  end

  def private_branch_command
    ret = BranchPackage.new(params).branch
    if ret[:text]
      render plain: ret[:text]
    else
      Event::BranchCommand.create project: params[:project], package: params[:package],
                                  targetproject: params[:target_project], targetpackage: params[:target_package],
                                  user: User.current.login
      render_ok ret
    end
  end

  # rubocop:disable Metrics/LineLength
  # POST /source/<project>/<package>?cmd=branch&target_project="optional_project"&target_package="optional_package"&update_project_attribute="alternative_attribute"&comment="message"
  # rubocop:enable Metrics/LineLength
  def package_command_branch
    # find out about source and target dependening on command   - FIXME: ugly! sync calls

    # The branch command may be used just for simulation
    verify_can_modify_target! if !params[:dryrun] && @target_project_name

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
      if params[:flag] == 'access' && params[:status] == 'enable' && !@project.enabled_for?('access', params[:repository], params[:arch])
        raise Project::ForbiddenError
      end
      if params[:flag] == 'sourceaccess' && params[:status] == 'enable' &&
         !@project.enabled_for?('sourceaccess', params[:repository], params[:arch])
        raise Project::ForbiddenError
      end
    end

    obj_set_flag(@project)
  end

  class InvalidFlag < APIException; end

  def obj_set_flag(obj)
    obj.transaction do
      begin
        if params[:product]
          obj.set_repository_by_product(params[:flag], params[:status], params[:product])
        else
          # first remove former flags of the same class
          obj.remove_flag(params[:flag], params[:repository], params[:arch])
          obj.add_flag(params[:flag], params[:status], params[:repository], params[:arch])
        end
      rescue ArgumentError => e
        raise InvalidFlag, e.message
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
