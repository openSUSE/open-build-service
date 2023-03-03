class Webui::ProjectController < Webui::WebuiController
  include Webui::RequestHelper
  include Webui::ProjectHelper
  include Webui::ManageRelationships

  before_action :lockout_spiders, only: [:requests, :buildresults]

  before_action :require_login, only: [:create, :destroy, :new, :release_request,
                                       :new_release_request, :edit_comment]

  before_action :set_project, only: [:autocomplete_repositories, :users, :subprojects,
                                     :edit, :release_request,
                                     :show, :buildresult,
                                     :destroy, :remove_path_from_target,
                                     :requests, :save, :monitor, :edit_comment,
                                     :unlock, :save_person, :save_group, :remove_role,
                                     :move_path, :clear_failed_comment, :pulse,
                                     :keys_and_certificates]

  before_action :set_project_by_id, only: :update

  before_action :load_project_info, only: :show

  before_action :check_ajax, only: [:buildresult, :edit_comment_form]

  after_action :verify_authorized, except: [:index, :autocomplete_projects, :autocomplete_incidents, :autocomplete_packages,
                                            :autocomplete_repositories, :users, :subprojects, :new, :show,
                                            :buildresult, :requests, :monitor, :new_release_request,
                                            :remove_target_request, :edit_comment, :edit_comment_form,
                                            :keys_and_certificates]

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
    @bugowners_mail = @project.bugowner_emails
    @release_targets = @project.release_targets

    @has_patchinfo = @project.patchinfos.exists?
    @comments = @project.comments
    @comment = Comment.new

    if User.session && params[:notification_id]
      @current_notification = Notification.find(params[:notification_id])
      authorize @current_notification, :update?, policy_class: NotificationPolicy
    end

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

    @project.relationships.build(user: User.session!,
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
      redirect_back(fallback_location: root_path)
    end
  end

  def update
    authorize @project, :update?
    respond_to do |format|
      if @project.update(project_params)
        format.html do
          flash[:success] = 'Project was successfully updated.'
          redirect_to project_show_path(@project)
        end
        format.js { flash.now[:success] = 'Project was successfully updated.' }
      else
        format.html do
          flash[:error] = 'Failed to update project'
          redirect_to project_show_path(@project)
        end
        format.js
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
      authorize @current_notification, :update?, policy_class: NotificationPolicy
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
      rescue Patchinfo::IncompletePatchinfo,
             BsRequestActionMaintenanceRelease::ArchitectureOrderMissmatch,
             BsRequestActionMaintenanceRelease::OpenReleaseRequests,
             BsRequestActionMaintenanceRelease::RepositoryWithoutReleaseTarget,
             BsRequestActionMaintenanceRelease::RepositoryWithoutArchitecture,
             BsRequestAction::BuildNotFinished,
             BsRequestAction::VersionReleaseDiffers,
             BsRequestAction::UnknownProject,
             BsRequestAction::Errors::UnknownTargetProject,
             BsRequestAction::UnknownTargetPackage => e
        flash[:error] = e.message
        redirect_back(fallback_location: { action: 'show', project: params[:project] }) && return
      rescue APIError
        flash[:error] = 'Internal problem while release request creation'
        redirect_back(fallback_location: { action: 'show', project: params[:project] }) && return
      end
    end
    redirect_to action: 'show', project: params[:project]
  end

  def buildresult
    render partial: 'buildstatus', locals: { project: @project,
                                             buildresults: @project.buildresults,
                                             collapsed_repositories: params.fetch(:collapsedRepositories, {}) }
  end

  def requests
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
      redirect_back(fallback_location: root_path)
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
      redirect_back(fallback_location: root_path, error: "Can not remove path: #{@project.errors.full_messages.to_sentence}")
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
    unless (buildresult = monitor_buildresult)
      @buildresult_unavailable = true
      return
    end

    monitor_parse_buildresult(buildresult)

    # extract repos
    repohash = {}
    @statushash.each do |repo, arch_hash|
      repohash[repo] = arch_hash.keys.sort!
    end
    @repoarray = repohash.sort
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
    unless User.session!.can_create_attribute_in?(@package, at)
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

  def keys_and_certificates; end

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

  def monitor_buildresult
    @legend = Buildresult::STATUS_DESCRIPTION

    @name_filter = params[:pkgname]
    @lastbuild_switch = params[:lastbuild]
    # FIXME: this code needs some love
    defaults = if params[:defaults]
                 (begin
                   Integer(params[:defaults])
                 rescue ArgumentError
                   1
                 end).positive?
               else
                 true
               end
    params['expansionerror'] = 1 if params['unresolvable']
    monitor_set_filter(defaults)

    find_opt = { project: @project, view: 'status', code: @status_filter,
                 arch: @arch_filter, repository: @repo_filter }
    find_opt[:lastbuild] = 1 if @lastbuild_switch.present?

    buildresult = Buildresult.find_hashed(find_opt)
    if buildresult.empty?
      flash[:warning] = "No build results for project '#{elide(@project.name)}'"
      redirect_to action: :show, project: params[:project]
      return
    end

    return unless buildresult.key?('result')

    buildresult
  end

  def monitor_parse_buildresult(buildresult)
    @packagenames = Set.new
    @statushash = {}
    @repostatushash = {}
    @repostatusdetailshash = {}
    @failures = 0

    buildresult.elements('result') do |result|
      monitor_parse_result(result)
    end

    # convert to sorted array
    @packagenames = @packagenames.to_a.sort!
  end

  def monitor_parse_result(result)
    repo = result['repository']
    arch = result['arch']

    return unless @repo_filter.nil? || @repo_filter.include?(repo)
    return unless @arch_filter.nil? || @arch_filter.include?(arch)

    # package status cache
    @statushash[repo] ||= {}
    stathash = @statushash[repo][arch] = {}

    result.elements('status') do |status|
      package = status['package']
      next if @name_filter.present? && !filter_matches?(package, @name_filter)

      stathash[package] = status
      @packagenames.add(package)
      @failures += 1 if status['code'].in?(['unresolvable', 'failed', 'broken'])
    end

    # repository status cache
    @repostatushash[repo] ||= {}
    @repostatusdetailshash[repo] ||= {}

    return unless result.key?('state')

    @repostatushash[repo][arch] = if result.key?('dirty')
                                    'outdated_' + result['state']
                                  else
                                    result['state']
                                  end

    @repostatusdetailshash[repo][arch] = result['details'] if result.key?('details')
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
      :url
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
    @incoming_requests_size = OpenRequestsFinder.new(BsRequest, @project.name).count_incoming(reqs.values.sum)
    @outgoing_requests_size = OpenRequestsFinder.new(BsRequest, @project.name).count_outgoing(reqs.values.sum)

    @nr_of_problem_packages = @project.number_of_build_problems
  end

  def require_maintenance_project
    unless @is_maintenance_project
      redirect_back(fallback_location: { action: 'show', project: @project })
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

    @is_maintenance_project = @project.is_maintenance?
    if @is_maintenance_project
      @open_maintenance_incidents = @project.maintenance_incidents.distinct.order('projects.name').pluck('projects.name')

      @maintained_projects = @project.maintained_project_names
    end
    @is_incident_project = @project.is_maintenance_incident?
    return unless @is_incident_project

    @open_release_requests = BsRequest.find_for(project: @project.name,
                                                states: ['new', 'review'],
                                                types: ['maintenance_release'],
                                                roles: ['source']).pluck(:number)
  end

  def valid_target_name?(name)
    name =~ /^\w[-.\w&]*$/
  end

  def monitor_set_filter(defaults)
    @avail_status_values = Buildresult.avail_status_values
    @status_filter = []
    @avail_status_values.each do |s|
      id = s.delete(' ')
      if params.key?(id)
        next if params[id].to_s == '0'
      else
        next unless defaults
      end
      next if defaults && ['disabled', 'excluded', 'unknown'].include?(s)

      @status_filter << s
    end

    repos = @project.repositories
    @avail_repo_values = repos.select(:name).distinct.order(:name).pluck(:name)
    @avail_arch_values = repos.joins(:architectures).select('architectures.name').distinct.order('architectures.name').pluck('architectures.name')

    @arch_filter = []
    @avail_arch_values.each do |s|
      archid = valid_xml_id("arch_#{s}")
      @arch_filter << s if defaults || params[archid]
    end

    @repo_filter = []
    @avail_repo_values.each do |s|
      repoid = valid_xml_id("repo_#{s}")
      @repo_filter << s if defaults || params[repoid]
    end
  end

  def filter_matches?(input, filter_string)
    result = false
    filter_string.gsub!(/\s*/, '')
    filter_string.split(',').each do |filter|
      no_invert = filter.match(/(^!?)(.+)/)
      result = if no_invert[1] == '!'
                 input.include?(no_invert[2]) ? result : true
               else
                 input.include?(no_invert[2]) ? true : result
               end
    end
    result
  end

  def set_project_by_name
    @project = Project.get_by_name(params['project'])
  rescue Project::UnknownObjectError
    @project = nil
  end
end
