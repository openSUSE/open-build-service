class Webui::RequestController < Webui::WebuiController
  helper 'webui/package'

  before_action :require_login,
                except: [:show, :sourcediff, :diff, :request_action, :request_action_changes, :inline_comment, :build_results, :rpm_lint, :changes, :mentioned_issues]
  # requests do not really add much value for our page rank :)
  before_action :lockout_spiders
  before_action :require_request,
                only: [:changerequest, :show, :request_action, :request_action_changes, :inline_comment, :build_results, :rpm_lint, :changes, :mentioned_issues]
  before_action :set_actions, only: [:inline_comment, :show, :build_results, :rpm_lint, :changes, :mentioned_issues],
                              if: -> { Flipper.enabled?(:request_show_redesign, User.session) }
  before_action :set_supported_actions, only: [:inline_comment, :show, :build_results, :rpm_lint, :changes, :mentioned_issues],
                                        if: -> { Flipper.enabled?(:request_show_redesign, User.session) }
  before_action :set_action_id, only: [:inline_comment, :show, :build_results, :rpm_lint, :changes, :mentioned_issues],
                                if: -> { Flipper.enabled?(:request_show_redesign, User.session) }
  before_action :set_active_action, only: [:inline_comment, :show, :build_results, :rpm_lint, :changes, :mentioned_issues],
                                    if: -> { Flipper.enabled?(:request_show_redesign, User.session) }
  before_action :set_superseded_request, only: [:show, :request_action, :request_action_changes, :build_results, :rpm_lint, :changes, :mentioned_issues]
  before_action :check_ajax, only: :sourcediff
  before_action :prepare_request_data, only: [:show, :build_results, :rpm_lint, :changes, :mentioned_issues],
                                       if: -> { Flipper.enabled?(:request_show_redesign, User.session) }
  before_action :cache_diff_data, only: [:show, :build_results, :rpm_lint, :changes, :mentioned_issues],
                                  if: -> { Flipper.enabled?(:request_show_redesign, User.session) }
  before_action :check_beta_user_redirect, only: [:build_results, :rpm_lint, :changes, :mentioned_issues]

  after_action :verify_authorized, only: [:create]

  def show
    # TODO: Remove this `if` condition, and the `else` clause once request_show_redesign is rolled out
    if Flipper.enabled?(:request_show_redesign, User.session)
      @active_tab = 'conversation'
      render :beta_show
    else
      @diff_limit = params[:full_diff] ? 0 : nil
      @diff_to_superseded_id = params[:diff_to_superseded]
      @is_author = @bs_request.creator == User.possibly_nobody.login

      @is_target_maintainer = @bs_request.is_target_maintainer?(User.session)
      @can_handle_request = @bs_request.state.in?([:new, :review, :declined]) && (@is_target_maintainer || @is_author)

      @history = @bs_request.history_elements.includes(:user)

      # retrieve a list of all package maintainers that are assigned to at least one target package
      @package_maintainers = target_package_maintainers

      # search for a project, where the user is not a package maintainer but a project maintainer and show
      # a hint if that package has some package maintainers (issue#1970)
      @show_project_maintainer_hint = !@package_maintainers.empty? && @package_maintainers.exclude?(User.session) && any_project_maintained_by_current_user?
      @comments = @bs_request.comments
      @comment = Comment.new

      handle_notification

      @actions = @bs_request.webui_actions(filelimit: @diff_limit, tarlimit: @diff_limit, diff_to_superseded: @diff_to_superseded, diffs: false)
      @action = @actions.first
      @active = @action[:name]
      # print a hint that the diff is not fully shown (this only needs to be verified for submit actions)
      @not_full_diff = BsRequest.truncated_diffs?(@actions)

      reviews = @bs_request.reviews.where(state: 'new')
      user = User.session # might be nil
      @my_open_reviews = reviews.select { |review| review.matches_user?(user) }
      @can_add_reviews = @bs_request.state.in?([:new, :review]) && (@is_author || @is_target_maintainer || @my_open_reviews.present?)

      respond_to do |format|
        format.html
        format.js { render_request_update }
      end
    end
  end

  def create
    @bs_request = BsRequest.new(bs_request_params)
    @bs_request.set_add_revision if params.key?(:add_revision)
    authorize @bs_request, :create?

    begin
      @bs_request.save!
      redirect_to request_show_path(@bs_request.number)
      return
    # FIXME: Use validations in the model instead of raising whenever something is wrong
    rescue BsRequestAction::MissingAction
      flash[:error] = 'Unable to submit, sources are unchanged'
    rescue Project::Errors::UnknownObjectError
      flash[:error] = "Unable to submit: The source of package #{elide(params[:project_name])}/#{elide(params[:package_name])} is broken"
    rescue APIError, ActiveRecord::RecordInvalid => e
      flash[:error] = e.message
    rescue Backend::Error => e
      flash[:error] = e.summary
    end

    if params.key?(:package_name)
      redirect_to(package_show_path(params[:project_name], params[:package_name]))
    else
      redirect_to(project_show_path(params[:project_name]))
    end
  end

  def add_reviewer
    request = BsRequest.find_by_number(params[:number])
    if request.nil?
      flash[:error] = "Unable to add review to request with id '#{params[:number]}': the request was not found."
    else
      begin
        request.addreview(addreview_opts)
      rescue BsRequestPermissionCheck::AddReviewNotPermitted
        flash[:error] = "Not permitted to add a review to '#{params[:number]}'"
      rescue ActiveRecord::RecordInvalid, APIError => e
        flash[:error] = "Unable to add review to request with id '#{params[:number]}': #{e.message}"
      end
    end
    redirect_to controller: :request, action: 'show', number: params[:number]
  end

  def modify_review_set_request
    review_params = params.slice(:comment, :review_id)
    review = Review.find_by(id: review_params[:review_id])
    unless review
      flash[:error] = 'Unable to load review'
      return review_params, nil
    end
    review_params[:by_package] = review.by_package
    review_params[:by_project] = review.by_project
    review_params[:by_user] = review.by_user
    review_params[:by_group] = review.by_group
    [review_params, review.bs_request]
  end

  def modify_review
    review_params, request = modify_review_set_request
    if request.nil?
      flash[:error] = 'Unable to load request'
      redirect_back(fallback_location: user_path(User.session!))
      return
    elsif !new_state.in?(['accepted', 'declined'])
      flash[:error] = 'Unknown state to set'
    else
      begin
        request.permission_check_change_review!(review_params)
        request.change_review_state(new_state, review_params)
        flash[:success] = 'Successfully submitted review'
      rescue BsRequestPermissionCheck::ReviewChangeStateNoPermission => e
        flash[:error] = "Not permitted to change review state: #{e.message}"
      rescue APIError => e
        flash[:error] = "Unable changing review state: #{e.message}"
      end
    end

    redirect_to request_show_path(number: request)
  end

  # TODO: Remove this once request_show_redesign is rolled out
  def request_action
    @diff_limit = params[:full_diff] ? 0 : nil
    @index = params[:index].to_i
    @actions = @bs_request.webui_actions(filelimit: @diff_limit, tarlimit: @diff_limit, diff_to_superseded: @diff_to_superseded, diffs: true,
                                         action_id: params['id'].to_i, cacheonly: 1)
    @action = @actions.find { |action| action[:id] == params['id'].to_i }
    @active = @action[:name]
    @not_full_diff = BsRequest.truncated_diffs?(@actions)
    @diff_to_superseded_id = params[:diff_to_superseded]

    if @action[:diff_not_cached]
      bs_request_action = BsRequestAction.find(@action[:id])
      job = Delayed::Job.where('handler LIKE ?', "%job_class: BsRequestActionWebuiInfosJob%#{bs_request_action.to_global_id.uri}%").count
      BsRequestActionWebuiInfosJob.perform_later(bs_request_action) if job.zero?
    end

    respond_to do |format|
      format.js
    end
  end

  def request_action_changes
    # TODO: Change @diff_limit to a local variable
    @diff_limit = params[:full_diff] ? 0 : nil
    # TODO: Change @actions to a local variable
    @actions = @bs_request.webui_actions(filelimit: @diff_limit, tarlimit: @diff_limit, diff_to_superseded: @diff_to_superseded, diffs: true,
                                         action_id: params['id'].to_i, cacheonly: 1)
    @action = @actions.find { |action| action[:id] == params['id'].to_i }
    # TODO: Check if @not_full_diff is really needed
    @not_full_diff = BsRequest.truncated_diffs?(@actions)
    # TODO: Check if @diff_to_superseded_id is really needed
    @diff_to_superseded_id = params[:diff_to_superseded]

    cache_diff_data

    respond_to do |format|
      format.js
    end
  end

  def sourcediff
    render partial: 'webui/shared/editor', locals: { text: params[:text],
                                                     mode: 'diff', style: { read_only: true },
                                                     height: 'auto', width: '750px',
                                                     no_border: true, uid: params[:uid] }
  end

  def changerequest
    changestate = (['accepted', 'declined', 'revoked', 'new'] & params.keys).last

    if change_state(changestate, params)
      # TODO: Make this work for each submit action individually
      if params[:add_submitter_as_maintainer_0]
        if changestate == 'accepted'
          # split into project and package
          tprj, tpkg = params[:add_submitter_as_maintainer_0].split('_#_')
          target = if tpkg
                     Package.find_by_project_and_name(tprj, tpkg)
                   else
                     Project.find_by_name(tprj)
                   end
          # the request action type might be permitted in future, but that doesn't mean we
          # are allowed to modify the object
          target.add_maintainer(@bs_request.creator) if target.can_be_modified_by?(User.possibly_nobody)
        else
          flash[:error] = 'Will not add maintainer for not accepted requests'
        end
      end
      accept_request if changestate == 'accepted'
    end
    redirect_to(request_show_path(params[:number]))
  end

  def diff
    # just for compatibility. OBS 1.X used this route for show
    redirect_to action: :show, number: params[:number]
  end

  def list_small
    redirect_to(user_path(User.possibly_nobody)) && return unless request.xhr? # non ajax request

    requests = BsRequest.list(params)
    render partial: 'requests_small', locals: { requests: requests }
  end

  def set_bugowner_request
    required_parameters :project
    request = nil
    begin
      request = BsRequest.create!(
        description: params[:description], bs_request_actions: [BsRequestAction.new(request_action_attributes(:set_bugowner))]
      )
    rescue APIError => e
      flash[:error] = e.message
      redirect_to(controller: :package, action: :show, package: params[:package], project: params[:project]) && return if params[:package]

      redirect_to(controller: :project, action: :show, project: params[:project]) && return
    end
    redirect_to controller: :request, action: :show, number: request.number
  end

  def set_incident
    request = BsRequest.find_by_number(params[:number])
    if request.nil?
      flash[:error] = 'Unable to load request'
    elsif params[:incident_project].blank?
      flash[:error] = 'Unknown incident project to set'
    else
      begin
        request.setincident(params[:incident_project])
        flash[:success] = "Set target of request #{request.number} to incident #{params[:incident_project]}"
      rescue Project::UnknownObjectError => e
        flash[:error] = "Incident #{e.message} does not exist"
      rescue APIError => e
        flash[:error] = "Not able to set incident: #{e.message}"
      end
    end

    redirect_to action: 'show', number: params[:number]
  end

  # used by mixins
  def main_object
    BsRequest.find_by_number(params[:number])
  end

  def inline_comment
    @line = params[:line]
    respond_to do |format|
      format.js
    end
  end

  def build_results
    redirect_to request_show_path(params[:number], params[:request_action_id]) unless @action[:sprj] || @action[:spkg]

    @active_tab = 'build_results'
    @project = @staging_project || @action[:sprj]
    @buildable = @action[:spkg] || @project

    @ajax_data = {}
    @ajax_data['project'] = @project if @project
    @ajax_data['package'] = @action[:spkg] if @action[:spkg]
  end

  def rpm_lint
    redirect_to request_show_path(params[:number], params[:request_action_id]) unless @action[:sprj] || @action[:spkg]

    @active_tab = 'rpm_lint'
    @ajax_data = {}
    @ajax_data['project'] = @action[:sprj] if @action[:sprj]
    @ajax_data['package'] = @action[:spkg] if @action[:spkg]
    @ajax_data['is_staged_request'] = true if @staging_project.present?
  end

  def changes
    redirect_to request_show_path(params[:number], params[:request_action_id]) unless @action[:type].in?(@actions_for_diff)

    @active_tab = 'changes'
  end

  def mentioned_issues
    redirect_to request_show_path(params[:number], params[:request_action_id]) unless @action[:type].in?(@actions_for_diff)

    @active_tab = 'mentioned_issues'
  end

  private

  def check_beta_user_redirect
    redirect_to request_show_path(params[:number], params[:request_action_id]) unless Flipper.enabled?(:request_show_redesign, User.session)
  end

  def addreview_opts
    opts = {}
    case params[:review_type]
    when 'review-user'
      opts[:by_user] = params[:review_user]
    when 'review-group'
      opts[:by_group] = params[:review_group]
    when 'review-project'
      opts[:by_project] = params[:review_project]
    when 'review-package'
      opts[:by_project] = params[:review_project]
      opts[:by_package] = params[:review_package]
    end
    opts[:comment] = params[:review_comment] if params[:review_comment]

    opts
  end

  def any_project_maintained_by_current_user?
    projects = @bs_request.bs_request_actions.select(:target_project).distinct.pluck(:target_project)
    maintainer_role = Role.find_by_title('maintainer')
    projects.any? { |project| Project.find_by_name(project).user_has_role?(User.possibly_nobody, maintainer_role) }
  end

  def new_state
    case params[:new_state]
    when 'Approve'
      'accepted'
    when 'Decline'
      'declined'
    end
  end

  def set_superseded_request
    return unless params[:diff_to_superseded]

    @diff_to_superseded = @bs_request.superseding.find_by(number: params[:diff_to_superseded])
    return if @diff_to_superseded

    flash[:error] = "Request #{params[:diff_to_superseded]} does not exist or is not superseded by request #{@bs_request.number}."
    nil
  end

  def require_request
    @bs_request = BsRequest.find_by!(number: params[:number])
  end

  def target_package_maintainers
    distinct_bs_request_actions = @bs_request.bs_request_actions.select(:target_project, :target_package).distinct
    distinct_bs_request_actions.flat_map do |action|
      Package.find_by_project_and_name(action.target_project, action.target_package).try(:maintainers)
    end.compact.uniq
  end

  def change_state(newstate, params)
    request = BsRequest.find_by_number(params[:number])
    if request.nil?
      flash[:error] = 'Unable to load request'
    else
      # FIXME: make force optional, it hides warnings!
      opts = {
        newstate: newstate,
        force: true,
        user: User.session!.login,
        comment: params[:reason]
      }
      begin
        request.change_state(opts)
        flash[:success] = "Request #{newstate}!"
        return true
      rescue APIError => e
        flash[:error] = "Failed to change state: #{e.message}!"
        return false
      end
    end

    false
  end

  def accept_request
    flash[:success] = "Request #{params[:number]} accepted"

    # Check if we have to forward this request to other projects / packages
    params.keys.grep(/^forward.*/).each do |fwd|
      forward_request_to(fwd)
    end
  end

  def forward_request_to(fwd)
    # split off 'forward_' and split into project and package
    tgt_prj, tgt_pkg = params[fwd].split('_#_')
    begin
      forwarded_request = @bs_request.forward_to(project: tgt_prj, package: tgt_pkg, options: params.slice(:description))
    rescue APIError, ActiveRecord::RecordInvalid => e
      error_string = "Failed to forward BsRequest: #{@bs_request.number}, error: #{e}, params: #{params.inspect}"
      error_string << ", request: #{e.record.inspect}" if e.respond_to?(:record)
      Airbrake.notify(error_string)
      flash[:error] = "Unable to forward submit request: #{e.message}"
      return
    end

    target_link = ActionController::Base.helpers.link_to("#{tgt_prj} / #{tgt_pkg}", package_show_url(project: tgt_prj, package: tgt_pkg))
    request_link = ActionController::Base.helpers.link_to("request #{forwarded_request.number}", request_show_path(forwarded_request.number))
    flash[:success] += " and forwarded to #{target_link} (#{request_link})"
  end

  def set_package
    return unless params.key?(:package_name)

    @package = Package.get_by_project_and_name(params[:project_name], params[:package_name],
                                               use_source: false, follow_project_links: true, follow_multibuild: true)
  rescue APIError
    raise ActiveRecord::RecordNotFound
  end

  # Subcontroller is expected to implement #bs_request_params
  # Strong parameters for BsRequest with nested attributes for its bs_request_actions association
  def bs_request_params
    raise AbstractMethodCalled
  end

  # FIXME: We should rely on strong parameters, so implement `bs_request_params` in subcontrollers as explained above
  def request_action_attributes(type)
    opt = {}
    opt['target_project'] = params[:project]
    opt['target_package'] = params[:package]
    opt['source_project'] = params[:devel_project]
    opt['source_package'] = params[:devel_package] || params[:package]
    opt['target_repository'] = params[:repository]
    opt['person_name'] = params[:user] if params[:user].present?
    opt['group_name'] = params[:group] if params[:group].present?
    opt['role'] = params[:role]
    opt['type'] = type.to_s
    opt
  end

  def render_request_update
    render partial: 'update', locals: {
      is_target_maintainer: @is_target_maintainer,
      is_author: @is_author,
      bs_request: @bs_request,
      history: @history,
      can_add_reviews: @can_add_reviews,
      package_maintainers: @package_maintainers,
      can_handle_request: @can_handle_request,
      my_open_reviews: @my_open_reviews,
      show_project_maintainer_hint: @show_project_maintainer_hint,
      actions: @actions
    }
  end

  def set_actions
    @actions = @bs_request.bs_request_actions
  end

  def set_supported_actions
    # Change supported_actions below into actions here when all actions are supported
    @supported_actions = @actions.where(type: [:add_role, :change_devel, :delete, :submit])
  end

  def set_action_id
    # In case the request doesn't have supported actions, we display the first unsupported action.
    @action_id = params[:request_action_id] || @supported_actions.first&.id || @actions.first.id
  end

  def set_active_action
    @active_action = @actions.find(@action_id)
  end

  def staging_status(request, target_project)
    return nil unless (staging_review = request.reviews.staging(target_project).last)

    if staging_review.for_project?
      staging_project = {
        name: staging_review.project.name[target_project.name.length + 1..],
        url: staging_workflow_staging_project_path(target_project.name, staging_review.project.name)
      }
    end

    {
      staging_project: staging_project,
      target_project_staging_url: staging_workflow_path(request.target_project_name)
    }
  end

  def cache_diff_data
    return unless @action[:diff_not_cached]

    bs_request_action = BsRequestAction.find(@action[:id])
    job = Delayed::Job.where('handler LIKE ?', "%job_class: BsRequestActionWebuiInfosJob%#{bs_request_action.to_global_id.uri}%").count
    BsRequestActionWebuiInfosJob.perform_later(bs_request_action) if job.zero?
  end

  def handle_notification
    return unless User.session && params[:notification_id]

    @current_notification = Notification.find(params[:notification_id])
    authorize @current_notification, :update?, policy_class: NotificationPolicy
  end

  def prepare_request_data
    @is_author = @bs_request.creator == User.possibly_nobody.login
    @is_target_maintainer = @bs_request.is_target_maintainer?(User.session)
    reviews = @bs_request.reviews.where(state: 'new')
    @my_open_reviews = reviews.select { |review| review.matches_user?(User.session) }
    @can_add_reviews = @bs_request.state.in?([:new, :review]) && (@is_author || @is_target_maintainer || @my_open_reviews.present?)

    @diff_limit = params[:full_diff] ? 0 : nil
    @diff_to_superseded_id = params[:diff_to_superseded]

    # Handling request actions
    @action = @bs_request.webui_actions(filelimit: @diff_limit, tarlimit: @diff_limit, diff_to_superseded: @diff_to_superseded,
                                        diffs: true, action_id: @action_id.to_i, cacheonly: 1).first
    active_action_index = @supported_actions.index(@active_action)
    if active_action_index
      @prev_action = @supported_actions[active_action_index - 1] unless active_action_index.zero?
      @next_action = @supported_actions[active_action_index + 1] if active_action_index + 1 < @supported_actions.length
    end

    target_project = Project.find_by_name(@bs_request.target_project_name)
    @request_reviews = @bs_request.reviews.for_non_staging_projects(target_project)
    @staging_status = staging_status(@bs_request, target_project) if Staging::Workflow.find_by(project: target_project)

    # Collecting all issues in a hash. Each key is the issue name and the value is a hash containing all the issue details.
    @issues = @action.fetch(:sourcediff, []).reduce({}) { |accumulator, sourcediff| accumulator.merge(sourcediff.fetch('issues', {})) }

    # retrieve a list of all package maintainers that are assigned to at least one target package
    @package_maintainers = target_package_maintainers

    # retrieve a list of all project maintainers
    @project_maintainers = target_project&.maintainers || []

    # search for a project, where the user is not a package maintainer but a project maintainer and show
    # a hint if that package has some package maintainers (issue#1970)
    @show_project_maintainer_hint = !@package_maintainers.empty? && @package_maintainers.exclude?(User.session) && any_project_maintained_by_current_user?

    # Handling build results
    @staging_project = @bs_request.staging_project.name unless @bs_request.staging_project_id.nil?
    @actions_for_diff = [:submit, :delete, :maintenance_incident, :maintenance_release]

    handle_notification
  end
end
