class SourceProjectController < SourceController
  include CheckAndRemoveRepositories
  include ReadAccessOfDeleted

  validate_action index: { method: :get, response: :directory }
  before_action :require_valid_project_name, except: :index

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

  # GET /source/:project
  def show
    project_name = params[:project]
    if params.key?(:deleted)
      unless Project.find_by_name(project_name) || Project.remote_project?(project_name)
        # project is deleted or not accessible
        validate_read_access_of_deleted_project(project_name)
      end
      pass_to_backend
      return
    end

    if Project.remote_project?(project_name)
      # not a local project, hand over to backend
      pass_to_backend
      return
    end

    @project = Project.find_by_name(project_name)
    raise Project::UnknownObjectError, "Project not found: #{project_name}" unless @project

    # we let the backend list the packages after we verified the project is visible
    if params.key?(:view)
      case params[:view]
      when 'verboseproductlist'
        @products = Product.all_products(@project, params[:expand])
        render 'source/verboseproductlist', formats: [:xml]
        return
      when 'productlist'
        @products = Product.all_products(@project, params[:expand])
        render 'source/productlist', formats: [:xml]
        return
      when 'issues'
        render_project_issues
      when 'info'
        pass_to_backend
      when 'versions'
        render_project_versions
      else
        raise InvalidParameterError, "'#{params[:view]}' is not a valid 'view' parameter value."
      end
      return
    end

    render_project_packages
  end

  def render_project_issues
    set_issues_defaults
    render partial: 'source/project_issues', formats: [:xml]
  end

  def render_project_versions
    @packages = @project.packages.includes(:latest_local_version, :latest_upstream_version).select(:id, :name)
    render partial: 'source/project_versions', formats: [:xml]
  end

  def render_project_packages
    @packages = params.key?(:expand) ? @project.expand_all_packages : @project.packages.pluck(:name)
    render locals: { expand: params.key?(:expand) }, formats: [:xml]
  end

  # DELETE /source/:project
  def delete
    project = Project.get_by_name(params[:project])

    # checks
    unless project.is_a?(Project) && User.session.can_modify?(project)
      logger.debug "No permission to delete project #{project}"
      render_error status: 403, errorcode: 'delete_project_no_permission',
                   message: "Permission denied (delete project #{project})"
      return
    end
    project.check_weak_dependencies!
    opts = { no_write_to_backend: true,
             force: params[:force].present?,
             recursive_remove: params[:remove_linking_repositories].present? }
    check_and_remove_repositories!(project.repositories, opts)

    logger.info "destroying project object #{project.name}"
    project.commit_opts = { comment: params[:comment] }
    begin
      project.destroy
    rescue ActiveRecord::RecordNotDestroyed => e
      exception_message = "Destroying Project #{project.name} failed: #{e.record.errors.full_messages.to_sentence}"
      logger.debug exception_message
      raise ActiveRecord::RecordNotDestroyed, exception_message
    end

    render_ok
  end

  # GET /source/:project/_pubkey
  def show_pubkey
    render plain: Backend::Api::Sources::Project.pubkey(params[:project], { rev: params[:rev] }.compact)
  end

  # DELETE /source/:project/_pubkey
  def delete_pubkey
    backend_params = {
      user: User.session.login,
      meta: params[:meta],
      comment: params[:comment]
    }.compact

    # check for permissions
    project_name = Project.get_by_name(params[:project]).name
    upper_project = project_name.gsub(/:[^:]*$/, '')
    while upper_project != project_name && upper_project.present?
      if Project.exists_by_name(upper_project) && User.session.can_modify?(Project.get_by_name(upper_project))
        render xml: Backend::Api::Sources::Project.delete_pubkey(params[:project], backend_params)
        return
      end
      break unless upper_project.include?(':')

      upper_project = upper_project.gsub(/:[^:]*$/, '')
    end

    if User.admin_session?
      render xml: Backend::Api::Sources::Project.delete_pubkey(params[:project], backend_params)
    else
      raise DeleteProjectPubkeyNoPermission, "No permission to delete public key for project '#{params[:project]}'. " \
                                             'Either maintainer permissions by upper project or admin permissions is needed.'
    end
  end
end
