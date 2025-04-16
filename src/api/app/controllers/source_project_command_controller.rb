class SourceProjectCommandController < SourceController
  before_action :require_valid_project_name

  # POST /source/:project?cmd
  #-----------------
  def project_command
    # init and validation
    #--------------------
    required_parameters(:cmd)

    valid_commands = %w[undelete showlinked remove_flag set_flag createpatchinfo
                        createkey extendkey copy createmaintenanceincident lock
                        unlock release addchannels modifychannels move freezelink]

    raise IllegalRequest, 'invalid_command' unless valid_commands.include?(params[:cmd])

    command = params[:cmd]
    project_name = params[:project]
    params[:user] = User.session.login

    return dispatch_command(:project_command, command) if command.in?(%w[undelete release copy move])

    @project = Project.get_by_name(project_name)

    raise CmdExecutionNoPermission, "no permission to execute command '#{command}'" unless
      (command == 'unlock' && User.session.can_modify?(@project, true)) ||
      command == 'showlinked' ||
      User.session.can_modify?(@project)

    dispatch_command(:project_command, command)
  end

  private

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

  # POST /source/<project>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def project_command_remove_flag
    required_parameters :flag
    obj_remove_flag(@project)
  end

  ##
  ## Helper Method
  ##

  def private_plain_backend_command
    # is there any value in this call?
    Project.find_by_name(params[:project])

    path = request.path_info
    path += build_query_from_hash(params, %i[cmd user comment days])
    pass_to_backend(path)
  end
end
