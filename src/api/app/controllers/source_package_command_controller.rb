require 'builder/xchar'

class SourcePackageCommandController < SourceController
  # we use an array for the "file" parameter
  skip_before_action :validate_params, only: %i[diff linkdiff servicediff]

  # diff: works on remote project strings
  before_action :set_project, except: :diff
  before_action :require_valid_project_name, only: :diff
  # copy: is copying *to* the package
  # diff: works on remote package strings
  # undelete: is about to re-create the package
  before_action :set_package, except: %i[diff copy undelete]
  before_action :require_valid_package_name, only: %i[copy undelete]
  before_action :set_origin_package, only: %i[copy diff]
  before_action :set_user_param
  # branch: everything is authorized in BranchPackage.branch
  # diff: is a read only command
  # fork: everything is authorized in BranchPackage.branch
  # getprojectservices: is a read only command
  # linkdiff: is a read only command
  # release: everything is authorized in MaintenanceHelper.release_package
  # servicediff: is a read only command
  # waitservice: is a read only command
  after_action :verify_authorized, except: %i[branch diff fork getprojectservices linkdiff release servicediff waitservice]

  # POST /source/<project>/<package>?cmd=updatepatchinfo
  def updatepatchinfo
    authorize @package, :update?

    Patchinfo.new.cmd_update_patchinfo(params[:project], params[:package])
    render_ok
  end

  # POST /source/<project>/<package>?cmd=importchannel
  def importchannel
    authorize @package, :update?

    repo = nil

    if params[:target_project]
      target_project = Project.find_by(name: params[:target_project])
      raise Project::Errors::UnknownObjectError, "Project not found: #{params[:target_project]}" unless target_project

      repo = Repository.find_by_project_and_name(params[:target_project], params[:target_repository])
    end

    import_channel(request.raw_post, @package, repo)

    render_ok
  end

  # POST /source/<project>/<package>?cmd=unlock
  def unlock
    authorize @package, :unlock?

    required_parameters :comment

    flag = @package.flags.find_by_flag_and_status('lock', 'enable')
    raise NotLocked, "package '#{@project.name}/#{@package.name}' is not locked" unless flag

    @package.flags.delete(f)
    @package.store({ comment: params[:comment] })

    render_ok
  end

  # add channel packages and extend repository list
  # POST /source/<project>/<package>?cmd=addchannels
  def addchannels
    authorize @package, :update?

    mode = :add_disabled
    mode = :skip_disabled if params[:mode] == 'skip_disabled'
    mode = :enable_all    if params[:mode] == 'enable_all'

    @package.add_channels(mode)

    render_ok
  end

  # add containers using the origin of this package (docker in first place, but not limited to it)
  # POST /source/<project>/<package>?cmd=addcontainers
  def addcontainers
    authorize @package, :update?

    @package.add_containers(extend_package_names: params[:extend_package_names].present?)

    render_ok
  end

  # add repositories and/or enable them for a specified channel
  # POST /source/<project>/<package>?cmd=enablechannel
  def enablechannel
    authorize @package, :update?

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
    if @package.readonly? # package comes from remote instance or is hidden
      # FIXME: we could request the links on remote instance but we would need to merge local and remote links...
      # path = "/search/package/id?match=(@linkinfo/package=\"#{CGI.escape(package_name)}\"+and+@linkinfo/project=\"#{CGI.escape(project_name)}\")"
      # answer = Backend::Connection.post path
      # render :text => answer.body, :content_type => 'text/xml'
      render xml: '<collection/>'
    else
      render 'source/package_command_showlinked', formats: [:xml]
    end
  end

  # POST /source/<project>/<package>?cmd=collectbuildenv
  def collectbuildenv
    authorize @package, :update?

    path = request.path_info
    path << build_query_from_hash(params, %i[cmd user comment orev oproject opackage])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=instantiate
  def instantiate
    authorize @project, :update?

    raise CmdExecutionNoPermission, 'package is already intialized here' if @project == @package.project
    raise CmdExecutionNoPermission, "no permission to execute command 'copy'" unless User.session.can_modify?(@project)
    raise CmdExecutionNoPermission, 'no permission to modify source package' unless User.session.can_modify?(@package, true)

    opts = {}
    at = AttribType.find_by_namespace_and_name!('OBS', 'MakeOriginOlder')
    opts[:makeoriginolder] = true if params[:makeoriginolder] || @project.attribs.find_by(attrib_type: at)
    instantiate_container(@project, @package.update_instance, opts)
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
    authorize @package, :update?

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
    authorize @package

    if params[:repo] && @project.repositories.find_by(name: params[:repo]).empty?
      render_error status: 400, errorcode: 'unknown_repository',
                   message: "Unknown repository '#{params[:repo]}'"
      return
    end

    Backend::Api::Sources::Package.rebuild(@project.name, @package.name, { repository: params[:repo], arch: params[:arch] })

    render_ok
  end

  # POST /source/<project>/<package>?cmd=commit
  def commit
    authorize @package, :update?

    path = request.path_info
    path += build_query_from_hash(params, %i[cmd user comment rev linkrev keeplink repairlink])
    pass_to_backend(path)

    @package.sources_changed
  end

  # POST /source/<project>/<package>?cmd=commitfilelist
  def commitfilelist
    authorize @package, :update?

    path = request.path_info
    path += build_query_from_hash(params, %i[cmd user comment rev linkrev keeplink repairlink withvalidate])
    answer = pass_to_backend(path)

    @package.sources_changed(dir_xml: answer)
  end

  # POST /source/<project>/<package>?cmd=diff
  def diff
    # oproject/opackage are optional for the backend, but we need them for authorization
    params[:oproject] ||= params[:project]
    params[:opackage] ||= params[:package]

    # for a local project we have to authorize read access (access / sourceaccess flags)
    project_package = {}
    project_package[params[:project]] = params[:package]
    project_package[params[:oproject]] = params[:opackage]
    project_package.each_pair do |project_name, package_name|
      project = Project.find_by(name: project_name) # read access
      next unless project

      package = Package.get_by_project_and_name(project.name, package_name,
                                                use_source: false,
                                                follow_project_links: true,
                                                follow_project_scmsync_links: true,
                                                follow_project_remote_links: true,
                                                follow_special_names: true)

      authorize package, :source_access?
    end

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
    authorize @project, :update?

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
    # parameter names are different between project and package release unfortunatly.
    params[:targetproject] = params[:target_project]
    params[:targetrepository] = params[:target_repository]
    verify_release_targets!(@package.project, params[:arch])

    if params[:target_project]
      required_parameters :repository, :target_repository

      target_project = Project.find_by!(name: params[:target_project])
      repository = @package.project.repositories.find_by!(name: params[:repository])
      target_repository = target_project.repositories.find_by!(name: params[:target_repository])

      release_package(@package,
                      target_repository,
                      @package.release_target_name(target_repository, Time.now.utc),
                      { filter_source_repository: repository,
                        multibuild_container: Package.multibuild_flavor(params[:package]),
                        filter_architecture: params[:arch],
                        setrelease: params[:setrelease],
                        manual: true,
                        comment: "Releasing package #{@package.name}" })
    else
      # loop via all defined targets
      @package.project.repositories.each do |repo|
        next if params[:repository] && params[:repository] != repo.name

        repo.release_targets.each do |releasetarget|
          next unless releasetarget.trigger.in?(%w[manual maintenance])

          # find md5sum and release source and binaries
          release_package(@package,
                          releasetarget.target_repository,
                          @package.release_target_name(releasetarget.target_repository, Time.now.utc),
                          { filter_source_repository: repo,
                            filter_architecture: params[:arch],
                            multibuild_container: Package.multibuild_flavor(params[:package]),
                            setrelease: params[:setrelease],
                            manual: true,
                            comment: "Releasing package #{@package.name}" })
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
    authorize @package, :update?

    path = request.path_info
    path += build_query_from_hash(params, %i[cmd comment user])
    pass_to_backend(path)

    @package.sources_changed
  end

  # POST /source/<project>/<package>?cmd=runservice
  def runservice
    authorize @package, :update?

    path = request.path_info
    path += build_query_from_hash(params, %i[cmd comment user])
    pass_to_backend(path)

    @package.sources_changed unless @package.readonly?
  end

  # POST /source/<project>/<package>?cmd=deleteuploadrev
  def deleteuploadrev
    authorize @package, :update?

    path = request.path_info
    path += build_query_from_hash(params, [:cmd])
    pass_to_backend(path)
  end

  # POST /source/<project>/<package>?cmd=linktobranch
  def linktobranch
    authorize @package, :update?

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

    branch
  end

  # POST /source/<project>/<package>?cmd=set_flag&repository=:opt&arch=:opt&flag=flag&status=status
  def set_flag
    authorize @package, :update?

    required_parameters :flag, :status
    obj_set_flag(@package)
  end

  # POST /source/<project>/<package>?cmd=remove_flag&repository=:opt&arch=:opt&flag=flag
  def remove_flag
    authorize @package, :update?

    required_parameters :flag
    obj_remove_flag(@package)
  end

  private

  def set_project
    @project = Project.find_by(name: params[:project])
    raise Project::Errors::UnknownObjectError, "Project not found: #{params[:project]}" unless @project
  end

  def set_package
    options = { updatepatchinfo: { follow_project_links: false },
                importchannel: { follow_project_links: false },
                unlock: { follow_project_links: false },
                addchannels: { follow_project_links: false },
                addcontainers: { follow_project_links: false },
                enablechannel: { follow_project_links: false },
                getprojectservices: { follow_project_links: false, follow_project_scmsync_links: true, follow_project_remote_links: true, follow_special_names: true },
                showlinked: { follow_project_scmsync_links: true, follow_project_remote_links: true, follow_special_names: true },
                collectbuildenv: { follow_project_links: false },
                instantiate: { follow_project_links: false, check_update_project: true },
                createSpecFileTemplate: { follow_project_links: false },
                rebuild: { follow_project_scmsync_links: true, follow_project_remote_links: true, follow_special_names: true },
                commit: { follow_project_links: false },
                commitfilelist: { follow_project_links: false },
                linkdiff: { follow_project_scmsync_links: true, follow_project_remote_links: true, follow_special_names: true },
                servicediff: { follow_project_scmsync_links: true, follow_project_remote_links: true, follow_special_names: true },
                release: { follow_project_links: false, follow_project_scmsync_links: true, follow_project_remote_links: true, follow_multibuild: true, follow_special_names: true },
                waitservice: { follow_project_scmsync_links: true, follow_project_remote_links: true, follow_special_names: true },
                mergeservice: { follow_project_links: false },
                runservice: { follow_project_links: false, follow_project_scmsync_links: true, follow_project_remote_links: true },
                deleteuploadrev: { follow_project_links: false },
                linktobranch: { follow_project_links: false },
                branch: { follow_project_links: true, follow_project_scmsync_links: true, follow_project_remote_links: true },
                fork: { follow_project_links: true, follow_project_scmsync_links: true, follow_project_remote_links: true },
                set_flag: { follow_project_links: false },
                remove_flag: { follow_project_links: false } }.freeze

    @package = Package.get_by_project_and_name(@project.name, params[:package], options[params[:cmd].to_sym])
  end

  def require_valid_package_name
    return if Package.valid_name?(params[:package], allow_multibuild: params[:cmd] == 'release')

    raise InvalidPackageNameError, "invalid package name '#{params[:package]}'"
  end

  def set_user_param
    params[:user] = User.session.login
  end

  def set_origin_package
    return nil unless params[:opackage]

    required_parameters(:oproject)
    raise InvalidPackageNameError, "invalid package name '#{params[:opackage]}'" unless Package.valid_name?(params[:opackage])
    raise InvalidProjectNameError, "invalid project name '#{params[:oproject]}'" unless Project.valid_name?(params[:oproject])

    @origin_package = Package.get_by_project_and_name(params[:oproject], params[:opackage], follow_special_names: params[:cmd] == 'diff')
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
end
