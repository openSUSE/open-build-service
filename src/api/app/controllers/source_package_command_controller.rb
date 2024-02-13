require 'builder/xchar'

class SourcePackageCommandController < ApplicationController
  include MaintenanceHelper
  include Source::Errors
  include VerifyReleaseTargets
  include SetFlag

  SOURCE_UNTOUCHED_COMMANDS = ['branch', 'diff', 'linkdiff', 'servicediff', 'showlinked', 'rebuild', 'wipe',
                               'waitservice', 'remove_flag', 'set_flag', 'getprojectservices'].freeze
  # list of cammands which create the target package
  PACKAGE_CREATING_COMMANDS = ['branch', 'release', 'copy', 'undelete', 'instantiate'].freeze
  # list of commands which are allowed even when the project has the package only via a project link
  READ_COMMANDS = ['branch', 'diff', 'linkdiff', 'servicediff', 'showlinked', 'getprojectservices', 'release'].freeze
  # commands which are fine to operate on external scm managed projects
  SCM_SYNC_PROJECT_COMMANDS = ['diff', 'linkdiff', 'showlinked', 'copy', 'remove_flag', 'set_flag', 'runservice',
                               'waitservice', 'getprojectservices', 'unlock', 'wipe', 'rebuild', 'collectbuildenv'].freeze

  # we use an array for the "file" parameter in those actions
  skip_before_action :validate_params, only: [:diff, :linkdiff, :servicediff]

  before_action :require_valid_project_name
  before_action :set_target_project_and_package
  before_action :set_user_param
  before_action :validate_project_and_package_params
  before_action :set_missingok, only: [:branch, :release]
  before_action :require_skpg
  before_action :validate_package_creating_commands

  # Update issues in patchinfo
  # POST /source/<project>/<package>?cmd=updatepatchinfo
  def updatepatchinfo
    Patchinfo.new.cmd_update_patchinfo(params[:project], params[:package])
    render_ok
  end

  # Import _channel file
  # POST /source/<project>/<package>?cmd=importchannel
  def importchannel
    repo = nil
    repo = Repository.find_by_project_and_name(params[:target_project], params[:target_repository]) if params[:target_project]

    import_channel(request.raw_post, @package, repo)

    render_ok
  end

  # Unlock a package
  # POST /source/<project>/<package>?cmd=unlock
  def unlock
    required_parameters :comment

    p = { comment: params[:comment] }

    f = @package.flags.find_by_flag_and_status('lock', 'enable')
    raise NotLocked, "package '#{@package.project.name}/#{@package.name}' is not locked" unless f

    @package.flags.delete(f)
    @package.store(p)

    render_ok
  end

  # Add channel packages and extend repository list
  # POST /source/<project>/<package>?cmd=addchannels
  def addchannels
    mode = :add_disabled
    mode = :skip_disabled if params[:mode] == 'skip_disabled'
    mode = :enable_all    if params[:mode] == 'enable_all'

    @package.add_channels(mode)

    render_ok
  end

  # Add containers using the origin of this package (docker in first place, but not limited to it)
  # POST /source/<project>/<package>?cmd=addcontainers
  def addcontainers
    @package.add_containers(extend_package_names: params[:extend_package_names].present?)

    render_ok
  end

  # Add repositories and/or enable them for a specified channel
  # POST /source/<project>/<package>?cmd=enablechannel
  def enablechannel
    @package.modify_channel(:enable_all)
    @package.project.store(user: User.session!.login)

    render_ok
  end

  # Collect all project source services for a package
  # POST /source/<project>/<package>?cmd=getprojectservices
  def getprojectservices
    path = request.path_info
    path += build_query_from_hash(params, [:cmd])
    pass_to_backend(path)
  end

  # Create a collection of all package id's doing a package source link to this one
  # POST /source/<project>/<package>?cmd=showlinked
  def showlinked
    if @package
      render 'source/package_command_showlinked', formats: [:xml]
    else
      # package comes from remote instance or is hidden

      # FIXME: return an empty list for now
      # we could request the links on remote instance via that: but we would need to search also localy and merge ...

      # path = "/search/package/id?match=(@linkinfo/package=\"#{CGI.escape(package_name)}\"+and+@linkinfo/project=\"#{CGI.escape(project_name)}\")"
      # answer = Backend::Connection.post path
      # render :text => answer.body, :content_type => 'text/xml'
      render xml: '<collection/>'
    end
  end

  # POST /source/<project>/<package>?cmd=collectbuildenv
  def collectbuildenv
    required_parameters :oproject, :opackage

    Package.get_by_project_and_name(@target_project_name, @target_package_name)

    path = request.path_info
    path << build_query_from_hash(params, [:cmd, :user, :comment, :orev, :oproject, :opackage])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=instantiate
  def instantiate
    project = Project.get_by_name(params[:project])
    opackage = Package.get_by_project_and_name(project.name, params[:package], check_update_project: true)
    raise RemoteProjectError, 'Instantiation from remote project is not supported' unless opackage
    raise CmdExecutionNoPermission, 'package is already intialized here' if project == opackage.project
    raise CmdExecutionNoPermission, "no permission to execute command 'copy'" unless User.session!.can_modify?(project)
    raise CmdExecutionNoPermission, 'no permission to modify source package' unless User.session!.can_modify?(opackage, true) # ignore_lock option

    opts = {}
    at = AttribType.find_by_namespace_and_name!('OBS', 'MakeOriginOlder')
    opts[:makeoriginolder] = true if project.attribs.find_by(attrib_type: at) # object or nil
    opts[:makeoriginolder] = true if params[:makeoriginolder]
    instantiate_container(project, opackage.update_instance, opts)
    render_ok
  end

  # POST /source/<project>/<package>?cmd=undelete
  def undelete
    raise PackageExists, "the package exists already #{@target_project_name} #{@target_package_name}" if Package.exists_by_project_and_name(@target_project_name, @target_package_name, follow_project_links: false)

    tprj = Project.get_by_name(@target_project_name)
    raise CmdExecutionNoPermission, "no permission to create package in project #{@target_project_name}" unless tprj.is_a?(Project) && Pundit.policy(User.session!, Package.new(project: tprj)).create?

    path = request.path_info
    raise CmdExecutionNoPermission, 'Only administrators are allowed to set the time' unless User.admin_session? || params[:time].blank?

    path += build_query_from_hash(params, [:cmd, :user, :comment, :time])
    pass_to_backend(path)

    # read meta data from backend to restore database object
    prj = Project.find_by_name!(params[:project])
    pkg = prj.packages.new(name: params[:package])
    pkg.update_from_xml(Xmlhash.parse(Backend::Api::Sources::Package.meta(params[:project], params[:package])))
    pkg.store
    pkg.sources_changed
  end

  # FIXME: Obsolete this for 3.0
  # POST /source/<project>/<package>?cmd=createSpecFileTemplate
  def create_spec_file_template
    begin
      # TODO: No need to read the whole file for knowing if it exists already
      Backend::Api::Sources::Package.file(params[:project], params[:package], "#{params[:package]}.spec")
      render_error status: 400, errorcode: 'spec_file_exists',
                   message: 'SPEC file already exists.'
      return
    rescue Backend::NotFoundError
      specfile_content = Rails.root.join('files/specfiletemplate').read
      Backend::Api::Sources::Package.write_file(params[:project], params[:package], "#{params[:package]}.spec", specfile_content)
    end
    render_ok
  end

  # FIXME: Obsolete this for 3.0: we have /build/ controller for this
  # POST /source/<project>/<package>?cmd=rebuild
  def rebuild
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
  def commit
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :user, :comment, :rev, :linkrev, :keeplink, :repairlink])
    pass_to_backend(path)

    @package.sources_changed if @package # except in case of _project package
  end

  # POST /source/<project>/<package>?cmd=commitfilelist
  def commitfilelist
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :user, :comment, :rev, :linkrev, :keeplink, :repairlink, :withvalidate])
    answer = pass_to_backend(path)

    @package.sources_changed(dir_xml: answer) if @package # except in case of _project package
  end

  # POST /source/<project>/<package>?cmd=diff
  def diff
    # oproject_name = params[:oproject]
    # opackage_name = params[:opackage]

    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :rev, :orev, :oproject, :opackage, :expand, :linkrev, :olinkrev,
                                           :unified, :missingok, :meta, :file, :filelimit, :tarlimit,
                                           :view, :withissues, :onlyissues, :cacheonly, :nodiff])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=linkdiff
  def linkdiff
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :rev, :unified, :linkrev, :file, :filelimit, :tarlimit,
                                           :view, :withissues, :onlyissues])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=servicediff
  def servicediff
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :rev, :unified, :file, :filelimit, :tarlimit, :view, :withissues, :onlyissues])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=copy
  def copy
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
    pass_to_backend(path)

    @package.sources_changed
  end

  # POST /source/<project>/<package>?cmd=release
  def release
    pkg = Package.get_by_project_and_name(params[:project], params[:package], follow_project_links: false, follow_multibuild: true)
    multibuild_container = nil
    multibuild_container = params[:package].gsub(/^.*:/, '') if params[:package].include?(':') && !params[:package].starts_with?('_product:')

    # uniq timestring for all targets
    time_now = Time.now.utc

    # specified target
    if params[:target_project]
      raise MissingParameterError, 'release action with specified target project needs also "repository" and "target_repository" parameter' if params[:target_repository].blank? || params[:repository].blank?

      # we do not create it ourself
      Project.get_by_name(params[:target_project])
      # parameter names are different between project and package release unfortunatly.
      params[:targetproject] = params[:target_project]
      params[:targetrepository] = params[:target_repository]
      verify_release_targets!(pkg.project)
      release_manual_target(pkg, multibuild_container, time_now)
    else
      verify_release_targets!(pkg.project)

      # loop via all defined targets
      pkg.project.repositories.each do |repo|
        next if params[:repository] && params[:repository] != repo.name

        repo.release_targets.each do |releasetarget|
          next unless releasetarget.trigger.in?(['manual', 'maintenance'])

          # find md5sum and release source and binaries
          release_package(pkg,
                          releasetarget.target_repository,
                          pkg.release_target_name(releasetarget.target_repository, time_now),
                          { filter_source_repository: repo,
                            filter_architecture: params[:arch],
                            multibuild_container: multibuild_container,
                            setrelease: params[:setrelease],
                            manual: true,
                            comment: "Releasing package #{pkg.name}" })
        end
      end
    end

    render_ok
  end

  # POST /source/<project>/<package>?cmd=waitservice
  def waitservice
    path = request.path_info
    path += build_query_from_hash(params, [:cmd])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=mergeservice
  def mergeservice
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend(path)

    @package.sources_changed
  end

  # POST /source/<project>/<package>?cmd=runservice
  def runservice
    path = request.path_info
    path += build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend(path)

    @package.sources_changed unless @project.scmsync.present? || params[:package] == '_project'
  end

  # POST /source/<project>/<package>?cmd=deleteuploadrev
  def deleteuploadrev
    path = request.path_info
    path += build_query_from_hash(params, [:cmd])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=linktobranch
  def linktobranch
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

  # POST /source/<project>/<package>?cmd=branch&target_project="optional_project"&target_package="optional_package"&update_project_attribute="alternative_attribute"&comment="message"
  def branch
    # find out about source and target dependening on command   - FIXME: ugly! sync calls

    # The branch command may be used just for simulation
    verify_can_modify_target! if !params[:dryrun] && @target_project_name

    ret = BranchPackage.new(params).branch
    if ret[:text]
      render plain: ret[:text]
    else
      Event::BranchCommand.create(project: params[:project], package: params[:package],
                                  targetproject: params[:target_project], targetpackage: params[:target_package],
                                  user: User.session!.login)
      render_ok ret
    end
  end

  # POST /source/<project>/<package>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def set_flag
    required_parameters :flag, :status

    obj_set_flag(@package)
  end

  # POST /source/<project>/<package>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def remove_flag
    required_parameters :flag
    @package.transaction do
      @package.remove_flag(params[:flag], params[:repository], params[:arch])
      @package.store
    end
    render_ok
  end

  private

  # FIXME: for 3.0, api of branch and copy calls have target and source in the opposite place
  def set_target_project_and_package
    if params[:cmd].in?(['branch', 'release'])
      @target_package_name = params[:package]
      @target_project_name = params[:target_project] # might be nil
      @target_package_name = params[:target_package] if params[:target_package]
    else
      @target_project_name = params[:project]
      @target_package_name = params[:package]
    end
  end

  def set_deleted_package
    @deleted_package = params.key?(:deleted)
  end

  def set_user_param
    params[:user] = User.session!.login
  end

  def validate_project_and_package_params
    if params[:oproject]
      origin_project_name = params[:oproject]
      valid_project_name!(origin_project_name)
    end
    if params[:opackage]
      origin_package_name = params[:opackage]
      valid_package_name!(origin_package_name)
    end

    required_parameters :oproject if origin_package_name

    valid_project_name!(params[:target_project]) if params[:target_project]
    valid_package_name!(params[:target_package]) if params[:target_package]
  end

  def set_missingok
    @missingok = true if params[:missingok]
  end

  # Check for existence/access of origin package when specified
  def require_skpg
    return unless params[:oproject] && params[:opackage]

    # Check for existence/access of origin project
    Project.get_by_name(params[:oproject])

    return if params[:opackage].in?(['_project', '_pattern'])
    return if @missingok

    @spkg = Package.get_by_project_and_name(params[:oproject], params[:opackage])
  end

  # FIXME: All this shit is before actions or god knows what...
  def validate_package_creating_commands
    return unless PACKAGE_CREATING_COMMANDS.include?(action_name)

    return unless Project.exists_by_name(@target_project_name)

    valid_project_name!(params[:project])
    # FIXME: wipe and rebuild should support multibuild as well
    if action_name == 'release'
      valid_multibuild_package_name!(params[:package])
    else
      valid_package_name!(params[:package])
    end
    # even when we can create the package, an existing instance must be checked if permissions are right
    @project = Project.get_by_name(@target_project_name)
    if (PACKAGE_CREATING_COMMANDS.exclude?(action_name) || Package.exists_by_project_and_name(@target_project_name,
                                                                                              @target_package_name,
                                                                                              follow_project_links: SOURCE_UNTOUCHED_COMMANDS.include?(action_name))) && (@project.is_a?(String) || @project.scmsync.blank? || SCM_SYNC_PROJECT_COMMANDS.exclude?(action_name))
      # is a local project, which is not scm managed. Or using a command not supported for scm projects.
      validate_target_for_package_command_exists!
    end
  end

  def verify_can_modify_target!
    # we require a target, but are we allowed to modify the existing target ?
    if Project.exists_by_name(@target_project_name)
      @project = Project.get_by_name(@target_project_name)
    else
      return if User.session!.can_create_project?(@target_project_name)

      raise CreateProjectNoPermission, "no permission to create project #{@target_project_name}"
    end

    if Package.exists_by_project_and_name(@target_project_name, @target_package_name, follow_project_links: false)
      verify_can_modify_target_package!
    elsif !@project.is_a?(Project) || !Pundit.policy(User.session!, Package.new(project: @project)).create?
      raise CmdExecutionNoPermission, "no permission to create package in project #{@target_project_name}"
    end
  end

  def verify_can_modify_target_package!
    return if User.session!.can_modify?(@package)

    unless @package.instance_of?(Package)
      raise CmdExecutionNoPermission, "no permission to execute command '#{params[:cmd]}' " \
                                      'for unspecified package'
    end
    raise CmdExecutionNoPermission, "no permission to execute command '#{params[:cmd]}' " \
                                    "for package #{@package.name} in project #{@package.project.name}"
  end

  def release_manual_target(pkg, multibuild_container, time_now)
    verify_can_modify_target!

    targetrepo = Repository.find_by_project_and_name(@target_project_name, params[:target_repository])
    raise UnknownRepository, "Repository does not exist #{params[:target_repository]}" unless targetrepo

    repo = pkg.project.repositories.where(name: params[:repository])
    raise UnknownRepository, "Repository does not exist #{params[:repository]}" unless repo.count.positive?

    repo = repo.first

    release_package(pkg,
                    targetrepo,
                    pkg.release_target_name(targetrepo, time_now),
                    { filter_source_repository: repo,
                      multibuild_container: multibuild_container,
                      filter_architecture: params[:arch],
                      setrelease: params[:setrelease],
                      manual: true,
                      comment: "Releasing package #{pkg.name}" })
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

  def validate_target_for_package_command_exists!
    @project = nil
    @package = nil

    follow_project_links = SOURCE_UNTOUCHED_COMMANDS.include?(action_name)

    unless @target_package_name.in?(['_project', '_pattern'])
      use_source = true
      use_source = false if action_name == 'showlinked'
      @package = Package.get_by_project_and_name(@target_project_name, @target_package_name,
                                                 use_source: use_source, follow_project_links: follow_project_links)
      if @package # for remote package case it's nil
        @project = @package.project
        ignore_lock = action_name == 'unlock'
        raise CmdExecutionNoPermission, "no permission to modify package #{@package.name} in project #{@project.name}" unless READ_COMMANDS.include?(action_name) || User.session!.can_modify?(@package, ignore_lock)
      end
    end

    # check read access rights when the package does not exist anymore
    validate_read_access_of_deleted_package(@target_project_name, @target_package_name) if @package.nil? && @deleted_package
  end
end
