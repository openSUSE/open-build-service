class SourcePackageController < SourceController
  before_action :require_valid_project_name
  before_action :set_target_project_name, only: %i[show delete]
  before_action :set_target_package_name, only: %i[show delete]

  # GET /source/:project/:package
  def show
    if params.key?(:deleted)
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
  def delete
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

  private

  # GET /source/:project/:package?view=issues
  # called from show_package
  def show_package_issues
    raise NoLocalPackage, 'Issues can only be shown for local packages' unless @tpkg

    set_issues_defaults
    @tpkg.update_if_dirty
    render partial: 'package_issues'
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
end
