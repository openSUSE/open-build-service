require 'builder/xchar'

class SourceController < ApplicationController
  include MaintenanceHelper
  include ValidationHelper

  include Source::Errors

  validate_action index: { method: :get, response: :directory }

  skip_before_action :extract_user, only: %i[lastevents_public global_command_orderkiwirepos global_command_triggerscmsync]
  skip_before_action :require_login, only: %i[lastevents_public global_command_orderkiwirepos global_command_triggerscmsync]

  before_action :require_valid_project_name, except: %i[index lastevents lastevents_public
                                                        global_command_orderkiwirepos global_command_branch
                                                        global_command_triggerscmsync global_command_createmaintenanceincident]

  before_action :require_scmsync_host_check, only: [:global_command_triggerscmsync]

  before_action :require_package, only: %i[show_package delete_package]

  # GET /source
  #########
  def index
    # init and validation
    #--------------------
    admin_user = User.admin_session?

    # access checks
    #--------------

    if params.key?(:deleted)
      raise NoPermissionForDeleted unless admin_user

      pass_to_backend
    else
      @project_names = Project.order(:name).pluck(:name)
      render formats: [:xml]
    end
  end

  # GET /source/:project/:package
  def show_package
    if @deleted_package
      tpkg = Package.find_by_project_and_name(@target_project_name, @target_package_name)
      raise PackageExists, 'the package is not deleted' if tpkg

      validate_read_access_of_deleted_package(@target_project_name, @target_package_name)
    elsif %w[_project _pattern].include?(@target_package_name)
      Project.get_by_name(@target_project_name)
    else
      @tpkg = Package.get_by_project_and_name(@target_project_name, @target_package_name)
    end

    show_package_issues && return if params[:view] == 'issues'

    # exec
    path = request.path_info
    path += build_query_from_hash(params, %i[rev linkrev emptylink
                                             expand view extension
                                             lastworking withlinked meta
                                             deleted parse arch
                                             repository product nofilename])
    pass_to_backend(path)
  end

  # DELETE /source/:project/:package
  def delete_package
    # checks
    raise DeletePackageNoPermission, '_project package can not be deleted.' if @target_package_name == '_project'

    tpkg = Package.get_by_project_and_name(@target_project_name, @target_package_name,
                                           use_source: false, follow_project_links: false)

    raise DeletePackageNoPermission, "no permission to delete package #{@target_package_name} in project #{@target_project_name}" unless User.session.can_modify?(tpkg)

    # deny deleting if other packages use this as develpackage
    tpkg.check_weak_dependencies! unless params[:force] == '1'

    logger.info "destroying package object #{tpkg.name}"
    tpkg.commit_opts = { comment: params[:comment] }

    begin
      tpkg.destroy
    rescue ActiveRecord::RecordNotDestroyed => e
      exception_message = "Destroying Package #{tpkg.project.name}/#{tpkg.name} failed: #{e.record.errors.full_messages.to_sentence}"
      logger.debug exception_message
      raise ActiveRecord::RecordNotDestroyed, exception_message
    end

    render_ok
  end

  # GET /source/:project/_pubkey and /_sslcert
  def show_project_pubkey
    # assemble path for backend
    path = pubkey_path

    # GET /source/:project/_pubkey
    pass_to_backend(path)
  end

  # DELETE /source/:project/_pubkey
  def delete_project_pubkey
    params[:user] = User.session.login
    path = pubkey_path

    # check for permissions
    upper_project = @prj.name.gsub(/:[^:]*$/, '')
    while upper_project != @prj.name && upper_project.present?
      if Project.exists_by_name(upper_project) && User.session.can_modify?(Project.get_by_name(upper_project))
        pass_to_backend(path)
        return
      end
      break unless upper_project.include?(':')

      upper_project = upper_project.gsub(/:[^:]*$/, '')
    end

    if User.admin_session?
      pass_to_backend(path)
    else
      raise DeleteProjectPubkeyNoPermission, "No permission to delete public key for project '#{params[:project]}'. " \
                                             'Either maintainer permissions by upper project or admin permissions is needed.'
    end
  end

  # GET /source/:project/:package/:filename
  def show_file
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
      pack = Package.get_by_project_and_name(project_name, package_name)
      if pack
        # in case of project links, we need to rewrite the target
        project_name = pack.project.name
        package_name = pack.name
      end
    end

    path = Package.source_path(project_name, package_name, file)
    path += build_query_from_hash(params, %i[rev meta deleted limit expand view])
    pass_to_backend(path)
  end

  # PUT /source/:project/:package/:filename
  def update_file
    check_permissions_for_file

    raise PutFileNoPermission, "Insufficient permissions to store file in package #{@package_name}, project #{@project_name}" unless @allowed

    # _pattern was not a real package in former OBS 2.0 and before, so we need to create the
    # package here implicit to stay api compatible.
    # FIXME3.0: to be revisited
    if @package_name == '_pattern'
      if Package.exists_by_project_and_name(@project_name, @package_name,
                                            follow_project_links: false)
        @pack = Package.get_by_project_and_name(@project_name, @package_name,
                                                follow_project_links: false)
        # very unlikely... (actually this should be a 400 instead of 404)
        raise RemoteProjectError, 'Cannot modify a remote package' if @pack.nil?
      else
        @pack = Package.new(name: '_pattern', title: 'Patterns',
                            description: 'Package Patterns')
        @prj.packages << @pack
        @pack.save
      end
    end

    Package.verify_file!(@pack, params[:filename], request.raw_post)

    @path += build_query_from_hash(params, %i[user comment rev linkrev keeplink meta])
    pass_to_backend(@path)

    # update package timestamp and reindex sources
    return if params[:rev] == 'repository' || @package_name.in?(%w[_project _pattern])

    special_file = params[:filename].in?(%w[_aggregate _constraints _link _service _patchinfo _channel])
    @pack.sources_changed(wait_for_update: special_file) # wait for indexing for special files
  end

  # DELETE /source/:project/:package/:filename
  def delete_file
    check_permissions_for_file

    raise DeleteFileNoPermission, 'Insufficient permissions to delete file' unless @allowed

    @path += build_query_from_hash(params, %i[user comment meta rev linkrev keeplink])
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
    path = http_request_path

    # map to a GET, so we can X-forward it
    volley_backend_path(path) unless forward_from_backend(path)
  end

  # POST /source?cmd=createmaintenanceincident
  def global_command_createmaintenanceincident
    prj = Project.get_maintenance_project!
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

  # POST /source?cmd=triggerscmsync
  def global_command_triggerscmsync
    pass_to_backend("/source#{build_query_from_hash(params, %i[cmd scmrepository scmbranch isdefaultbranch])}")
  end

  def set_issues_defaults
    @filter_changes = @states = nil
    @filter_changes = params[:changes].split(',') if params[:changes]
    @states = params[:states].split(',') if params[:states]
    @login = params[:login]
  end

  private

  # before_action for show_package, delete_package and package_command
  def require_package
    # init and validation
    #--------------------
    @deleted_package = params.key?(:deleted)

    @target_package_name = params[:package]

    # FIXME: for OBS 3, api of branch and copy calls have target and source in the opposite place
    if params[:cmd].in?(%w[branch fork release])
      @target_project_name = params[:target_project] # might be nil
      @target_package_name = params[:target_package] if params[:target_package]
    else
      @target_project_name = params[:project]
    end
  end

  # GET /source/:project/:package?view=issues
  # called from show_package
  def show_package_issues
    raise NoLocalPackage, 'Issues can only be shown for local packages' unless @tpkg

    set_issues_defaults
    @tpkg.update_if_dirty
    render partial: 'package_issues'
  end

  def pubkey_path
    # check for project
    @prj = Project.get_by_name(params[:project])
    request.path_info + build_query_from_hash(params, %i[user comment meta rev])
  end

  def check_permissions_for_file
    @project_name = params[:project]
    @package_name = params[:package]
    @file = params[:filename]
    @path = Package.source_path(@project_name, @package_name, @file)

    # authenticate
    params[:user] = User.session.login

    @prj = Project.get_by_name(@project_name)
    @pack = nil
    @allowed = false

    if @package_name == '_project' || @package_name == '_pattern'
      @allowed = permissions.project_change?(@prj)

      raise WrongRouteForAttribute, "Attributes need to be changed through #{change_attribute_path(project: params[:project])}" if @file == '_attribute' && @package_name == '_project'
      raise WrongRouteForStagingWorkflow if @file == '_staging_workflow' && @package_name == '_project'
    else
      # we need a local package here in any case for modifications
      @pack = Package.get_by_project_and_name(@project_name, @package_name)
      # no modification or deletion of scmsynced projects and packages allowed
      check_for_scmsynced_package_and_project(project: @prj, package: @pack)
      @allowed = permissions.package_change?(@pack)
    end
  end

  def check_for_scmsynced_package_and_project(project:, package:)
    return unless package.try(:scmsync).present? || project.try(:scmsync).present?

    scmsync_url = project.try(:scmsync)
    scmsync_url ||= package.try(:scmsync)

    raise ScmsyncReadOnly, "Can not change files in SCM bridged packages and projects: #{scmsync_url}"
  end

  def actually_create_incident(project)
    raise ModifyProjectNoPermission, "no permission to modify project '#{project.name}'" unless User.session.can_modify?(project)

    incident = MaintenanceIncident.build_maintenance_incident(project, no_access: params[:noaccess].present?)

    if incident
      render_ok data: { targetproject: incident.project.name }
    else
      render_error status: 400, errorcode: 'incident_has_no_maintenance_project',
                   message: 'incident projects shall only create below maintenance projects'
    end
  end

  # create a id collection of all projects doing a project link to this one
  # POST /source/<project>?cmd=showlinked
  def project_command_showlinked
    render 'source/project_command_showlinked', formats: [:xml]
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
    pass_to_backend(request.path_info + build_query_from_hash(params, %i[cmd user comment]))
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
    @project.store(user: User.session.login)

    render_ok
  end

  def private_plain_backend_command
    # is there any value in this call?
    Project.find_by_name(params[:project])

    path = request.path_info
    path += build_query_from_hash(params, %i[cmd user comment days])
    pass_to_backend(path)
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
    raise CmdExecutionNoPermission, "no permission to execute command 'undelete'" unless User.session.can_create_project?(params[:project])

    Project.restore(params[:project])
    render_ok
  end

  # POST /source/<project>?cmd=release
  def project_command_release
    params[:user] = User.session.login

    @project = Project.get_by_name(params[:project], include_all_packages: true)
    verify_release_targets!(@project, params[:arch])

    if @project.is_a?(String) # remote project
      render_error status: 404, errorcode: 'remote_project',
                   message: 'The release from remote projects is currently not supported'
      return
    end

    if params.key?(:nodelay)
      @project.do_project_release(params)
      render_ok
    else
      # inject as job
      ProjectDoProjectReleaseJob.perform_later(
        @project.id,
        params.slice(:project, :targetproject, :targetreposiory, :repository, :arch, :setrelease, :user).permit!.to_h
      )
      render_invoked
    end
  end

  def _check_single_target!(source_repository, target_repository, filter_architecture)
    # checking write access and architectures
    raise UnknownRepository, 'Invalid source repository' unless source_repository
    raise UnknownRepository, 'Invalid target repository' unless target_repository
    raise CmdExecutionNoPermission, "no permission to write in project #{target_repository.project.name}" unless User.session.can_modify?(target_repository.project)

    source_repository.check_valid_release_target!(target_repository, filter_architecture)
  end

  def verify_release_targets!(pro, filter_architecture = nil)
    repo_matches = nil
    repo_bad_type = nil

    pro.repositories.each do |repo|
      next if params[:repository] && params[:repository] != repo.name

      if params[:targetproject] || params[:targetrepository]
        target_repository = Repository.find_by_project_and_name(params[:targetproject], params[:targetrepository])

        _check_single_target!(repo, target_repository, filter_architecture)

        repo_matches = true
      else
        repo.release_targets.each do |releasetarget|
          next unless releasetarget

          unless releasetarget.trigger.in?(%w[manual maintenance])
            repo_bad_type = true
            next
          end

          _check_single_target!(repo, releasetarget.target_repository, filter_architecture)

          repo_matches = true
        end
      end
    end
    raise NoMatchingReleaseTarget, 'Trigger is not set to manual in any repository' if repo_bad_type && !repo_matches

    raise NoMatchingReleaseTarget, 'No defined or matching release target' unless repo_matches
  end

  # POST /source/<project>?cmd=move&oproject=<project>
  def project_command_move
    raise CmdExecutionNoPermission, 'Admin permissions required. STOP SCHEDULER BEFORE.' unless User.admin_session?
    raise ProjectExists, 'Target project exists already.' if Project.exists_by_name(params[:project])

    begin
      project = Project.get_by_name(params[:oproject])
      commit = { login: User.session.login,
                 lowprio: 1,
                 comment: "Project move from #{params[:oproject]} to #{params[:project]}" }
      commit[:comment] = params[:comment] if params[:comment].present?
      Backend::Api::Sources::Project.move(params[:oproject], params[:project])
      project.name = params[:project]
      project.store(commit)
      # update meta data in all packages, they contain the project name as well
      project.packages.each { |package| package.store(commit) }
    rescue StandardError
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
    raise CmdExecutionNoPermission, "no permission to execute command 'copy'" unless (@project && User.session.can_modify?(@project)) ||
                                                                                     (@project.nil? && User.session.can_create_project?(project_name))

    oprj = Project.get_by_name(params[:oproject], include_all_packages: true)
    if (params.key?(:makeolder) || params.key?(:makeoriginolder)) && !User.session.can_modify?(oprj)
      raise CmdExecutionNoPermission,
            "no permission to execute command 'copy', requires modification permission in origin project"
    end

    raise RemoteProjectError, 'The copy from remote projects is currently not supported' if oprj.is_a?(String) # remote project

    unless User.admin_session?
      raise ProjectCopyNoPermission, 'no permission to copy project with binaries for non admins' if params[:withbinaries]

      unless oprj.is_a?(String)
        oprj.packages.each do |pkg|
          next unless pkg.disabled_for?('sourceaccess', nil, nil)

          raise ProjectCopyNoPermission, "no permission to copy project due to source protected package #{pkg.name}"
        end
      end
    end

    # create new project object based on oproject
    unless @project
      # rubocop:disable Metrics/BlockLength
      Project.transaction do
        if oprj.is_a?(String) # remote project
          rdata = Xmlhash.parse(Backend::Api::Sources::Project.meta(oprj))
          @project = Project.new(name: project_name, title: rdata['title'], description: rdata['description'])
        else # local project
          @project = Project.new(name: project_name, title: oprj.title, description: oprj.description)
          @project.save
          oprj.flags.each do |f|
            @project.flags.create(status: f.status, flag: f.flag, architecture: f.architecture, repo: f.repo) unless f.flag == 'lock'
          end
          oprj.linking_to.each do |lp|
            @project.linking_to.create!(linked_db_project_id: lp.linked_db_project_id,
                                        linked_remote_project_name: lp.linked_remote_project_name,
                                        vrevmode: lp.vrevmode,
                                        position: lp.position)
          end
          oprj.repositories.each do |repo|
            r = @project.repositories.create(name: repo.name,
                                             block: repo.block,
                                             linkedbuild: repo.linkedbuild,
                                             rebuild: repo.rebuild)
            repo.repository_architectures.each do |ra|
              r.repository_architectures.create!(architecture: ra.architecture, position: ra.position)
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
      # rubocop:enable Metrics/BlockLength
    end

    job_params = params.slice(
      :cmd, :user, :comment, :oproject, :withbinaries, :withhistory, :makeolder, :makeoriginolder, :noservice, :resign
    ).permit!.to_h
    job_params[:user] = User.session.login

    if params.key?(:nodelay)
      ProjectDoProjectCopyJob.perform_now(@project.id, job_params)
      render_ok
    else
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

  def private_branch_command
    ret = BranchPackage.new(params).branch
    if ret[:text]
      render plain: ret[:text]
    else
      Event::BranchCommand.create(project: params[:project], package: params[:package],
                                  targetproject: params[:target_project], targetpackage: params[:target_package],
                                  user: User.session.login)
      render_ok ret
    end
  end

  # POST /source/<project>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def project_command_set_flag
    required_parameters :flag, :status

    # Raising permissions afterwards is not secure. Do not allow this by default.
    unless User.admin_session?
      raise Project::ForbiddenError if params[:flag] == 'access' && params[:status] == 'enable' && !@project.enabled_for?('access', params[:repository], params[:arch])
      if params[:flag] == 'sourceaccess' && params[:status] == 'enable' &&
         !@project.enabled_for?('sourceaccess', params[:repository], params[:arch])
        raise Project::ForbiddenError
      end
    end

    obj_set_flag(@project)
  end

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

  # POST /source/<project>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def project_command_remove_flag
    required_parameters :flag
    obj_remove_flag(@project)
  end

  def obj_remove_flag(obj)
    obj.transaction do
      obj.remove_flag(params[:flag], params[:repository], params[:arch])
      obj.store
    end
    render_ok
  end

  def set_request_data
    @request_data = Xmlhash.parse(request.raw_post)
    return if @request_data

    render_error status: 400, errorcode: 'invalid_xml', message: 'Invalid XML'
  end

  def render_error_for_package_or_project(err_code, err_message, xml_obj, obj)
    render_error status: 400, errorcode: err_code, message: err_message if xml_obj && xml_obj != obj
  end

  def validate_xml_content(rdata_field, object, error_status, error_message)
    render_error_for_package_or_project(error_status,
                                        error_message,
                                        rdata_field,
                                        object)
  end
end
