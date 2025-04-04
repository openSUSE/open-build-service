class Webui::ProjectController < Webui::WebuiController
  include Webui::RequestHelper
  include Webui::ProjectHelper
  include Webui::ManageRelationships
  include Webui::NotificationsHandler
  include Webui::ProjectBuildResultParsing

  before_action :lockout_spiders, only: %i[requests buildresults]

  before_action :require_login, only: %i[create destroy new release_request
                                         new_release_request edit_comment]

  # rubocop:disable Rails/LexicallyScopedActionFilter
  # The methods save_person, save_group and remove_role are defined in Webui::ManageRelationships
  before_action :set_project, only: %i[autocomplete_repositories users subprojects
                                       edit release_request
                                       show buildresult
                                       destroy remove_path_from_target
                                       requests save monitor edit_comment
                                       unlock save_person save_group remove_role
                                       move_path clear_failed_comment pulse]
  # rubocop:enable Rails/LexicallyScopedActionFilter
  before_action :set_project_by_id, only: :update

  before_action :load_project_info, only: :show

  before_action :check_ajax, only: %i[buildresult edit_comment_form]

  after_action :verify_authorized, except: %i[index autocomplete_projects autocomplete_staging_projects
                                              autocomplete_incidents autocomplete_packages
                                              autocomplete_repositories users subprojects new show
                                              buildresult requests monitor new_release_request
                                              remove_target_request edit_comment edit_comment_form preview_description]

  def index
    respond_to do |format|
      format.html do
        render :index,
               locals: { important_projects: Project.very_important_projects_with_categories }
      end
      format.json { render json: ProjectDatatable.new(params, view_context: view_context, show_all: show_all?) }
    end
  end

  def show
    @release_targets = @project.release_targets

    @comments = @project.comments
    @comment = Comment.new
    @current_notification = handle_notification

    respond_to do |format|
      format.html
      format.js
    end
  end

  def new
    @project = Project.new
    @project.name = params[:name] if params[:name]
    @namespace = params[:namespace]

    @show_restore_message = params[:restore_option] && Project.deleted?(params[:name])
  end

  def edit
    authorize @project, :update?
    respond_to do |format|
      format.js
    end
  end

  def create
    params[:project][:name] = "#{params[:namespace]}:#{params[:project][:name]}" if params[:namespace]

    @project = Project.new(project_params)
    authorize(@project, :create?)

    if Project.deleted?(@project.name) && !params[:restore_option_provided]
      redirect_to(new_project_path(name: @project.name, restore_option: true))
      return
    end

    @project.relationships.build(user: User.session,
                                 role: Role.find_by_title('maintainer'))

    @project.kind = 'maintenance' if params[:maintenance_project]

    # TODO: do this with nested attributes
    @project.flags.new(status: 'disable', flag: 'access') if params[:access_protection]

    # TODO: do this with nested attributes
    @project.flags.new(status: 'disable', flag: 'sourceaccess') if params[:source_protection]

    # TODO: do this with nested attributes
    @project.flags.new(status: 'disable', flag: 'publish') if params[:disable_publishing]

    if @project.valid? && @project.store
      flash[:success] = "Project '#{elide(@project.name)}' was created successfully"
      redirect_to action: 'show', project: @project.name
    else
      flash[:error] = "Failed to save project '#{elide(@project.name)}'. #{@project.errors.full_messages.to_sentence}."
      redirect_back_or_to root_path
    end
  end

  def update
    authorize @project, :update?
    respond_to do |format|
      format.js do
        if @project.update(project_params)
          @project.store
          flash.now[:success] = 'Project was successfully updated.'
        else
          flash.now[:error] = 'Failed to update the project.'
        end
      end
    end
  end

  def destroy
    authorize @project, :destroy?
    if @project.check_weak_dependencies?
      parent = @project.parent
      @project.destroy
      flash[:success] = 'Project was successfully removed.'
      if parent
        redirect_to project_show_path(parent)
      else
        redirect_to(action: :index)
      end
    else
      redirect_to project_show_path(@project), error: "Project can't be removed: #{@project.errors.full_messages.to_sentence}"
    end
  end

  def autocomplete_projects
    render json: Project.autocomplete(params[:term], params[:local]).not_maintenance_incident.pluck(:name)
  end

  def autocomplete_staging_projects
    render json: Project.autocomplete(params[:term]).where.not(staging_workflow_id: nil).pluck(:name)
  end

  def autocomplete_incidents
    render json: Project.autocomplete(params[:term]).maintenance_incident.pluck(:name)
  end

  def autocomplete_packages
    @project = Project.find_by(name: params[:project])
    if @project
      render json: @project.packages.autocomplete(params[:term]).pluck(:name)
    else
      render json: nil
    end
  end

  def autocomplete_repositories
    render json: @project.repositories.order(:name).pluck(:name)
  end

  def users
    @users = @project.users
    @groups = @project.groups
    @roles = Role.local_roles
    if User.session && params[:notification_id]
      @current_notification = Notification.find(params[:notification_id])
      authorize @current_notification, :update?, policy_class: NotificationCommentPolicy
    end
    @current_request_action = BsRequestAction.find(params[:request_action_id]) if User.session && params[:request_action_id]
  end

  def subprojects
    respond_to do |format|
      format.html
      format.json do
        render json: ProjectDatatable.new(params, view_context: view_context, projects: project_for_datatable)
      end
    end
  end

  def release_request
    authorize @project, :update?
  end

  def new_release_request
    if params[:skiprequest]
      # FIXME2.3: do it directly here, api function missing
    else
      begin
        req = nil
        BsRequest.transaction do
          req = BsRequest.new
          req.description = params[:description]

          action = BsRequestActionMaintenanceRelease.new(source_project: params[:project])
          req.bs_request_actions << action

          req.save!
        end
        flash[:success] = 'Created maintenance release request ' \
                          "<a href='#{url_for(controller: 'request', action: 'show', number: req.number)}'>#{req.number}</a>"
      rescue ArchitectureOrderMissmatch,
             Patchinfo::IncompletePatchinfo,
             BsRequestActionMaintenanceRelease::OpenReleaseRequests,
             BsRequestActionMaintenanceRelease::RepositoryWithoutReleaseTarget,
             BsRequestActionMaintenanceRelease::RepositoryWithoutArchitecture,
             BsRequestAction::BuildNotFinished,
             BsRequestAction::VersionReleaseDiffers,
             BsRequestAction::UnknownProject,
             BsRequestAction::Errors::UnknownTargetProject,
             BsRequestAction::UnknownTargetPackage => e
        flash[:error] = e.message
        redirect_back_or_to({ action: 'show', project: params[:project] }) && return
      rescue APIError
        flash[:error] = 'Internal problem while release request creation'
        redirect_back_or_to({ action: 'show', project: params[:project] }) && return
      end
    end
    redirect_to action: 'show', project: params[:project]
  end

  def buildresult
    render partial: 'buildstatus', locals: { project: @project,
                                             buildresults: @project.buildresults,
                                             collapsed_repositories: params.fetch(:collapsedRepositories, {}) }
  end

  # TODO: Remove this once request_index beta is rolled out
  def requests
    redirect_to(projects_requests_path(@project)) if Flipper.enabled?(:request_index, User.session)

    @default_request_type = params[:type] if params[:type]
    @default_request_state = params[:state] if params[:state]
  end

  def restore
    project = Project.new(name: params[:project])
    authorize(project, :create?)

    if Project.deleted?(project.name)
      project = Project.restore(project.name)

      flash[:success] = "Project '#{elide(project.name)}' was restored successfully"
      redirect_to action: 'show', project: project.name
    else
      flash[:error] = 'Project was never deleted.'
      redirect_back_or_to root_path
    end
  end

  def remove_target_request
    req = nil
    begin
      BsRequest.transaction do
        req = BsRequest.new
        req.description = params[:description]

        opts = { target_project: params[:project] }
        opts[:target_repository] = params[:repository] if params[:repository]
        action = BsRequestActionDelete.new(opts)
        req.bs_request_actions << action

        req.save!
      end
      flash[:success] = "Created <a href='#{url_for(controller: 'request',
                                                    action: 'show',
                                                    number: req.number)}'>repository delete request #{req.number}</a>"
    rescue BsRequestAction::Errors::UnknownTargetProject,
           BsRequestAction::UnknownTargetPackage => e
      flash[:error] = e.message
      redirect_to(action: :index, controller: :repositories, project: params[:project]) && return
    end
    redirect_to controller: :request, action: :show, number: req.number
  end

  def remove_path_from_target
    authorize @project, :update?

    repository = @project.repositories.find(params[:repository])
    path_element = repository.path_elements.find(params[:path])
    path_element.destroy
    if @project.valid?
      @project.store
      redirect_to({ action: :index, controller: :repositories, project: @project }, success: 'Successfully removed path')
    else
      redirect_back_or_to root_path, error: "Can not remove path: #{@project.errors.full_messages.to_sentence}"
    end
  end

  def move_path
    authorize @project, :update?

    params.require(:direction)
    repository = @project.repositories.find(params[:repository])
    path_element = repository.path_elements.find(params[:path])

    if params[:direction] == 'up'
      PathElement.transaction do
        path_element.move_higher
      end
    end
    if params[:direction] == 'down'
      PathElement.transaction do
        path_element.move_lower
      end
    end

    @project.store
    redirect_to({ action: :index, controller: :repositories, project: @project }, success: "Path moved #{params[:direction]} successfully")
  end

  def monitor
    build_results = monitor_buildresult

    if build_results
      # This method sets a bunch of instance variables used in the view and below...
      monitor_parse_buildresult(build_results)

      # extract repos
      repohash = {}
      @statushash.each do |repo, arch_hash|
        repohash[repo] = arch_hash.keys.sort!
      end
      @repoarray = repohash.sort
    else
      @buildresult_unavailable = true
    end
  end

  def clear_failed_comment
    # FIXME: This should authorize destroy for all the attributes
    authorize @project, :update?

    packages = Package.where(project: @project, name: params[:package])
    packages.each do |package|
      package.attribs.where(attrib_type: AttribType.find_by_namespace_and_name('OBS', 'ProjectStatusPackageFailComment')).destroy_all
    end

    flash.now[:success] = 'Cleared comments for packages'

    respond_to do |format|
      format.html { redirect_to(project_status_path(@project), success: 'Cleared comments for packages.') }
      format.js { render 'clear_failed_comment' }
    end
  end

  # FIXME: This should authorize create on this attribute
  def edit_comment
    @package = @project.find_package(params[:package])

    at = AttribType.find_by_namespace_and_name!('OBS', 'ProjectStatusPackageFailComment')
    unless User.session.can_create_attribute_in?(@package, at)
      @comment = params[:last_comment]
      flash.now[:error] = "Can't create attributes in #{elide(@package.name)}"
      return
    end

    attr = @package.attribs.where(attrib_type: at).first_or_initialize
    v = attr.values.first_or_initialize
    v.value = params[:text]
    v.position = 1
    attr.save!
    v.save!
    @comment = params[:text]
  end

  def unlock
    authorize @project, :unlock?
    if @project.unlock(params[:comment])
      redirect_to project_show_path(@project), success: 'Successfully unlocked project'
    else
      redirect_to project_show_path(@project), error: "Project can't be unlocked: #{@project.errors.full_messages.to_sentence}"
    end
  end

  def preview_description
    markdown = helpers.render_as_markdown(params[:project][:description])
    respond_to do |format|
      format.json { render json: { markdown: markdown } }
    end
  end

  def buildresults; end
  def save; end
  def pulse; end
  def edit_comment_form; end

  private

  def show_all?
    params[:all].to_s.casecmp?('true')
  end

  def project_for_datatable
    case params[:type]
    when 'sibling project'
      @project.siblingprojects
    when 'subproject'
      @project.subprojects
    when 'parent project'
      @project.ancestors
    end
  end

  def set_project_by_id
    @project = Project.find(params[:id])
  end

  def main_object
    @project # used by mixins
  end

  def project_params
    params.require(:project).permit(
      :name,
      :namespace,
      :title,
      :description,
      :maintenance_project,
      :access_protection,
      :source_protection,
      :disable_publishing,
      :url,
      :report_bug_url
    )
  end

  ################################### Before filters ###################################

  def set_maintained_project
    @maintained_project = Project.find_by(name: params[:maintained_project])
    raise ActiveRecord::RecordNotFound unless @maintained_project
  end

  def load_project_info
    find_maintenance_infos

    @packages = @project.packages.pluck(:name)
    @inherited_packages = @project.expand_all_packages.find_all { |inherited_package| @packages.exclude?(inherited_package[0]) }
    @linking_projects = @project.linked_by_projects.pluck(:name)

    reqs = @project.open_requests
    @requests = (reqs[:reviews] + reqs[:targets] + reqs[:incidents] + reqs[:maintenance_release]).sort!.uniq
    @incoming_requests_size = OpenRequestsFinder.new(BsRequest, @project.name).incoming_requests(@requests).count
    @outgoing_requests_size = OpenRequestsFinder.new(BsRequest, @project.name).outgoing_requests(@requests).count

    @nr_of_problem_packages = @project.number_of_build_problems
  end

  def require_maintenance_project
    unless @is_maintenance_project
      redirect_back_or_to({ action: 'show', project: @project })
      return false
    end
    true
  end

  ################################### Helper methods ###################################

  def find_maintenance_infos
    @project.maintenance_projects.each do |pm|
      # FIXME: skip the non official ones
      @project_maintenance_project = pm.maintenance_project.name
    end

    @is_maintenance_project = @project.maintenance?
    if @is_maintenance_project
      @open_maintenance_incidents = @project.maintenance_incidents.distinct.order('projects.name').pluck('projects.name')

      @maintained_projects = @project.maintained_project_names
    end
    @is_incident_project = @project.maintenance_incident?
    return unless @is_incident_project

    @open_release_requests = BsRequest::FindFor::Query.new(project: @project.name,
                                                           states: %w[new review],
                                                           types: ['maintenance_release'],
                                                           roles: ['source']).all.pluck(:number) # rubocop:disable Rails/RedundantActiveRecordAllMethod
  end

  def valid_target_name?(name)
    name =~ /^\w[-.\w&]*$/
  end

  def set_project_by_name
    @project = Project.get_by_name(params['project'])
  rescue Project::UnknownObjectError
    @project = nil
  end
end
