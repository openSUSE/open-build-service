require 'builder/xchar'

class SourcePackageCommandController < SourceController
  # source and meta data of target is not modified
  SOURCE_UNTOUCHED_COMMANDS = %w[diff linkdiff servicediff showlinked rebuild wipe
                                 waitservice getprojectservices].freeze
  # list of cammands which can create the target package (some of them also the project)
  PACKAGE_CREATING_COMMANDS = %w[branch release copy undelete instantiate fork].freeze
  PROJECT_CREATING_COMMANDS = %w[branch fork].freeze
  # We need to have maintainership in the project, when the pakage comes from another project
  BINARY_COMMANDS = %w[rebuild wipe].freeze

  # we use an array for the "file" parameter
  skip_before_action :validate_params, only: %i[diff linkdiff servicediff]

  before_action :set_project, only: :undelete
  before_action :set_target_project_name
  before_action :set_target_package_name
  before_action :set_user_param
  before_action :set_origin_package
  before_action :validate_target_project_name
  before_action :validate_target_package_name
  before_action :validate_project_name
  before_action :validate_package_name
  before_action :check_target_permissions

  # POST /source/<project>/<package>?cmd=updatepatchinfo
  def updatepatchinfo
    Patchinfo.new.cmd_update_patchinfo(params[:project], params[:package])
    render_ok
  end

  # POST /source/<project>/<package>?cmd=importchannel
  def importchannel
    repo = nil
    repo = Repository.find_by_project_and_name(params[:target_project], params[:target_repository]) if params[:target_project]

    import_channel(request.raw_post, @package, repo)

    render_ok
  end

  # lock a package
  # POST /source/<project>/<package>?cmd=lock
  def lock
    if @project.scmsync.present? && !@package
      # a package within a backend managed project
      path = request.path_info
      path += build_query_from_hash(params, [:cmd])
      pass_to_backend(path)
      return
    end

    f = @package.flags.find_by_flag_and_status('lock', 'enable')
    raise Locked, "package '#{@package.project.name}/#{@package.name}' is already locked" if f

    # we should never have a lock-disable, but to be sure drop it in that case
    @package.flags.of_type('lock').delete_all

    @package.flags.create(flag: 'lock', status: 'enable')
    @package.store({ comment: params[:comment] })

    render_ok
  end

  # unlock a package
  # POST /source/<project>/<package>?cmd=unlock&comment=COMMENT
  def unlock
    required_parameters :comment

    if @project.scmsync.present? && !@package
      # a package within a backend managed project
      return Backend::Api::Sources::Package.unlock(@project.name, params[:package])
    end

    p = { comment: params[:comment] }

    f = @package.flags.find_by_flag_and_status('lock', 'enable')
    raise NotLocked, "package '#{@package.project.name}/#{@package.name}' is not locked" unless f

    @package.flags.delete(f)
    @package.store(p)

    render_ok
  end

  # add channel packages and extend repository list
  # POST /source/<project>/<package>?cmd=addchannels
  def addchannels
    mode = :add_disabled
    mode = :skip_disabled if params[:mode] == 'skip_disabled'
    mode = :enable_all    if params[:mode] == 'enable_all'

    @package.add_channels(mode)

    render_ok
  end

  # add containers using the origin of this package (docker in first place, but not limited to it)
  # POST /source/<project>/<package>?cmd=addcontainers
  def addcontainers
    @package.add_containers(extend_package_names: params[:extend_package_names].present?)

    render_ok
  end

  # add repositories and/or enable them for a specified channel
  # POST /source/<project>/<package>?cmd=enablechannel
  def enablechannel
    @package.modify_channel(:enable_all)
    @package.project.store(user: User.session.login)

    render_ok
  end

  # Collect all project source services for a package
  # POST /source/<project>/<package>?cmd=getprojectservices
  def getprojectservices
    path = request.path_info
    path += build_query_from_hash(params, [:cmd])
    pass_to_backend(path)
  end

  # create a id collection of all packages doing a package source link to this one
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
    path << build_query_from_hash(params, %i[cmd user comment orev oproject opackage])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=instantiate
  def instantiate
    opackage = Package.get_by_project_and_name(@project.name, params[:package], check_update_project: true)
    raise RemoteProjectError, 'Instantiation from remote project is not supported' unless opackage
    raise CmdExecutionNoPermission, 'package is already intialized here' if @project == opackage.project
    raise CmdExecutionNoPermission, "no permission to execute command 'copy'" unless User.session.can_modify?(@project)
    raise CmdExecutionNoPermission, 'no permission to modify source package' unless User.session.can_modify?(opackage, true) # ignore_lock option

    opts = {}
    at = AttribType.find_by_namespace_and_name!('OBS', 'MakeOriginOlder')
    opts[:makeoriginolder] = true if @project.attribs.find_by(attrib_type: at) # object or nil
    opts[:makeoriginolder] = true if params[:makeoriginolder]
    instantiate_container(@project, opackage.update_instance, opts)
    render_ok
  end

  # POST /source/<project>/<package>?cmd=undelete
  def undelete
    raise PackageExists, "the package '#{@project.name}/#{params[:package]}' exists" if Package.exists_by_project_and_name(@project.name, params[:package], follow_project_links: false)
    raise CmdExecutionNoPermission, 'Only administrators are allowed to set the time' unless User.admin_session? || params[:time].blank?

    package = @project.packages.new(name: params[:package])
    authorize package, :create?

    Backend::Api::Sources::Package.undelete(@project.name, package.name, params.slice(:user, :comment, :time).permit!.to_h)
    package.update_from_xml(Xmlhash.parse(Backend::Api::Sources::Package.meta(@project.name, package.name)))
    package.sources_changed

    render_ok
  end

  # FIXME: obsolete this for 3.0
  # POST /source/<project>/<package>?cmd=createSpecFileTemplate
  def createSpecFileTemplate # rubocop:disable Naming/MethodName
    begin
      # TODO: No need to read the whole file for knowing if it exists already
      Backend::Api::Sources::Package.file(params[:project], params[:package], "#{params[:package]}.spec")
      render_error status: 400, errorcode: 'spec_file_exists',
                   message: 'SPEC file already exists.'
      return
    rescue Backend::NotFoundError
      specfile_content = File.read(Rails.root.join('files/specfiletemplate').to_s)
      Backend::Api::Sources::Package.write_file(params[:project], params[:package], "#{params[:package]}.spec", specfile_content)
    end
    render_ok
  end

  # OBS 3.0: this should be obsoleted, we have /build/ controller for this
  # POST /source/<project>/<package>?cmd=rebuild
  def rebuild
    repo_name = params[:repo]
    arch_name = params[:arch]

    # check for sources in this or linked project
    unless @package
      # check if this is a package on a remote OBS instance
      answer = Package.exists_on_backend?(@target_project_name, @target_package_name)
      unless answer
        render_error status: 400, errorcode: 'unknown_package',
                     message: "Unknown package '#{params[:package]}'"
        return
      end
    end

    options = {}
    if repo_name
      if @project.repositories.find_by_name(repo_name).nil?
        render_error status: 400, errorcode: 'unknown_repository',
                     message: "Unknown repository '#{repo_name}'"
        return
      end
      options[:repository] = repo_name
    end
    options[:arch] = arch_name if arch_name

    Backend::Api::Sources::Package.rebuild(@project.name, @target_package_name, options)

    render_ok
  end

  # POST /source/<project>/<package>?cmd=commit
  def commit
    path = request.path_info
    path += build_query_from_hash(params, %i[cmd user comment rev linkrev keeplink repairlink])
    pass_to_backend(path)

    @package.sources_changed if @package # except in case of _project package
  end

  # POST /source/<project>/<package>?cmd=commitfilelist
  def commitfilelist
    path = request.path_info
    path += build_query_from_hash(params, %i[cmd user comment rev linkrev keeplink repairlink withvalidate])
    answer = pass_to_backend(path)

    @package.sources_changed(dir_xml: answer) if @package # except in case of _project package
  end

  # POST /source/<project>/<package>?cmd=diff
  def diff
    # oproject_name = params[:oproject]
    # opackage_name = params[:opackage]

    path = request.path_info
    path += build_query_from_hash(params, %i[cmd rev orev oproject opackage expand linkrev olinkrev
                                             unified missingok meta file filelimit tarlimit
                                             view withissues onlyissues cacheonly nodiff])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=linkdiff
  def linkdiff
    path = request.path_info
    path += build_query_from_hash(params, %i[cmd rev unified linkrev file filelimit tarlimit
                                             view withissues onlyissues])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=servicediff
  def servicediff
    path = request.path_info
    path += build_query_from_hash(params, %i[cmd rev unified file filelimit tarlimit view withissues onlyissues])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=copy
  def copy
    if @origin_package
      # use real source in case we followed project link
      sproject = params[:oproject] = @origin_package.project.name
      spackage = params[:opackage] = @origin_package.name
    else
      sproject = params[:oproject] || params[:project]
      spackage = params[:opackage] || params[:package]
    end

    # create target package, if it does not exist
    reparse_backend_package(spackage, sproject) unless @package

    # We need to use the project name of package object, since it might come via a project linked project
    path = @package.source_path
    path << build_query_from_hash(params, %i[cmd rev user comment oproject opackage orev expand
                                             keeplink repairlink linkrev olinkrev requestid
                                             withvrev noservice dontupdatesource])

    pass_to_backend(path)

    @package.sources_changed
  end

  # POST /source/<project>/<package>?cmd=release
  def release
    pkg = Package.get_by_project_and_name(params[:project], params[:package],
                                          follow_project_links: false,
                                          follow_multibuild: true,
                                          follow_project_scmsync_links: true)
    multibuild_container = Package.multibuild_flavor(params[:package])

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
      verify_release_targets!(pkg.project, params[:arch])
      _package_command_release_manual_target(pkg, multibuild_container, time_now)
    else
      verify_release_targets!(pkg.project, params[:arch])

      # loop via all defined targets
      pkg.project.repositories.each do |repo|
        next if params[:repository] && params[:repository] != repo.name

        repo.release_targets.each do |releasetarget|
          next unless releasetarget.trigger.in?(%w[manual maintenance])

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
    path += build_query_from_hash(params, %i[cmd comment user])
    pass_to_backend(path)

    @package.sources_changed
  end

  # POST /source/<project>/<package>?cmd=runservice
  def runservice
    path = request.path_info
    path += build_query_from_hash(params, %i[cmd comment user])
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
    if @target_package_name.in?(%w[_project _pattern])
      render_error status: 400, message: "cannot turn a #{@target_package_name} package into a branch"
      return
    end
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

  # POST /source/<project>/<package>?cmd=fork&scmsync="url"&target_project="optional_project"
  def fork
    raise MissingParameterError, 'scmsync url is not specified' if params[:scmsync].blank?

    ret = BranchPackage.new(params).branch
    if ret[:text]
      render plain: ret[:text]
    else
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
    obj_remove_flag(@package)
  end

  private

  def validate_project_name
    return if Project.valid_name?(params[:project])

    raise InvalidProjectNameError, "invalid project name '#{params[:project]}'"
  end

  def validate_package_name
    return if Package.valid_name?(params[:package], allow_multibuild: params[:cmd] == 'release')

    raise InvalidPackageNameError, "invalid package name '#{params[:package]}'"
  end

  def validate_target_project_name
    return unless params[:target_project]
    raise InvalidProjectNameError, "invalid project name '#{params[:target_project]}'" unless Project.valid_name?(params[:target_project])
  end

  def validate_target_package_name
    return unless params[:target_package]
    raise InvalidPackageNameError, "invalid package name '#{params[:target_package]}'" unless Package.valid_name?(params[:target_package])
  end

  def set_user_param
    params[:user] = User.session.login
  end

  def set_origin_package
    return nil unless params[:opackage]

    required_parameters(:oproject)
    raise InvalidPackageNameError, "invalid package name '#{params[:opackage]}'" unless Package.valid_name?(params[:opackage])
    raise InvalidProjectNameError, "invalid project name '#{params[:oproject]}'" unless Project.valid_name?(params[:oproject])

    return if %w[_project _pattern].include?(params[:opackage])
    return if %w[branch release].include?(params[:cmd]) && params[:missingok]

    @origin_package = Package.get_by_project_and_name(params[:oproject], params[:opackage])
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

  def _package_command_release_manual_target(pkg, multibuild_container, time_now)
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

  # The target is the object we operate on depending on the context of the operation.
  # if it is a changing operation, we need modification or creation rights, otherwise read access
  # also figure out the right object to check, esp. with project links, remote links and scmsync in mind
  def check_target_permissions
    @project = nil
    @package = nil
    follow_project_links = (SOURCE_UNTOUCHED_COMMANDS.include?(params[:cmd]) || BINARY_COMMANDS.include?(params[:cmd]))
    use_source = params[:cmd] != 'showlinked'
    ignore_lock = params[:cmd] == 'unlock'
    no_modification = SOURCE_UNTOUCHED_COMMANDS.include?(params[:cmd]) && !BINARY_COMMANDS.include?(params[:cmd])
    no_modification = true if params[:cmd] == "branch" && params[:dryrun]

    object_to_check = nil
    # check access for package object if it exists for the operation and we would not create it in absence
    unless @target_package_name.in?(%w[_project _pattern])
      if Package.exists_by_project_and_name(@target_project_name, @target_package_name, follow_project_links: follow_project_links) ||
         !PACKAGE_CREATING_COMMANDS.include?(params[:cmd])

        @package = Package.get_by_project_and_name(@target_project_name,
                                                   @target_package_name,
                                                   use_source: use_source,
                                                   follow_project_links: follow_project_links)
      end

      if @package
        object_to_check = @package
        @project = @package.project
      end
    end

    # our operation may happen in a different project as the the package lifes
    if Project.exists_by_name(@target_project_name) || !PROJECT_CREATING_COMMANDS.include?(params[:cmd])
      @project = Project.get_by_name(@target_project_name) if @target_project_name.present?
      object_to_check ||= @project
    end

    # not nice, but commands like release handle permissions themself as
    # they need to read it from their meta data (eg. releasetarget)
    return if PACKAGE_CREATING_COMMANDS.include?(params[:cmd]) && !Project.exists_by_name(@target_project_name)

    # we run in project context no matter where the source come from if
    if (@project.is_a?(Project) && @project.scmsync.present?) ||  # the project is managed via an scm
       BINARY_COMMANDS.include?(params[:cmd]) ||                  # or it is a binary operation
       (!@package.is_a?(Package) && PACKAGE_CREATING_COMMANDS.include?(params[:cmd]))# or package instance will get created
      object_to_check = @project
    end

    # Do we need to check for modification permissions?
    raise CmdExecutionNoPermission, "not a modifiable object" if !no_modification && (object_to_check.nil? || object_to_check.is_a?(String))
    unless no_modification || (!object_to_check.is_a?(String) && User.session.can_modify?(object_to_check, ignore_lock))
      raise CmdExecutionNoPermission, "no permission to modify package #{object_to_check.name} in project #{object_to_check.project.name}" if object_to_check.is_a?(Package)
      raise CmdExecutionNoPermission, "no permission to modify project #{object_to_check.name}"
    end

    # check read access rights when the package does not exist anymore
    validate_read_access_of_deleted_package(@target_project_name, @target_package_name) if @package.nil? && params.key?(:deleted)
  end
end
