class Webui::RequestController < Webui::WebuiController
  helper 'webui/package'

  before_action :require_login, except: [:show, :sourcediff, :diff]
  # requests do not really add much value for our page rank :)
  before_action :lockout_spiders
  before_action :require_request, only: [:changerequest, :show]
  before_action :set_superseded_request, only: :show
  before_action :check_ajax, only: :sourcediff

  after_action :verify_authorized, only: [:create]

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
      flash[:error] = "Unable to submit: The source of package #{params[:project_name]}/#{params[:package_name]} is broken"
    rescue APIError, ActiveRecord::RecordInvalid => e
      flash[:error] = e.message
    end

    if params.key?(:package_name)
      redirect_to(package_show_path(params[:project_name], params[:package_name]))
    else
      redirect_to(project_show_path(params[:project_name]))
    end
  end

  def add_reviewer
    begin
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

      request = BsRequest.find_by_number!(params[:number])
      request.addreview(opts)
    rescue BsRequestPermissionCheck::AddReviewNotPermitted
      flash[:error] = "Not permitted to add a review to '#{params[:number]}'"
    rescue ActiveRecord::RecordInvalid, APIError => e
      flash[:error] = "Unable add review to '#{params[:number]}': #{e.message}"
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

  def show
    diff_limit = params[:full_diff] ? 0 : nil

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

    @actions = @bs_request.webui_actions(filelimit: diff_limit, tarlimit: diff_limit, diff_to_superseded: @diff_to_superseded, diffs: true)
    # print a hint that the diff is not fully shown (this only needs to be verified for submit actions)
    @not_full_diff = BsRequest.truncated_diffs?(@actions)

    reviews = @bs_request.reviews.where(state: 'new')
    user = User.session # might be nil
    @my_open_reviews = reviews.select { |review| review.matches_user?(user) }
    @can_add_reviews = @bs_request.state.in?([:new, :review]) && (@is_author || @is_target_maintainer || @my_open_reviews.present?)
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
        if changestate != 'accepted'
          flash[:error] = 'Will not add maintainer for not accepted requests'
        else
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

  private

  def any_project_maintained_by_current_user?
    projects = @bs_request.bs_request_actions.select(:target_project).distinct.pluck(:target_project)
    maintainer_role = Role.find_by_title('maintainer')
    projects.any? { |project| Project.find_by_name(project).user_has_role?(User.possibly_nobody, maintainer_role) }
  end

  def new_state
    case params[:new_state]
    when 'Approve'
      'accepted'
    when 'Disregard'
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
    required_parameters :number
    @bs_request = BsRequest.find_by_number(params[:number])
    return if @bs_request

    flash[:error] = "Can't find request #{params[:number]}"
    redirect_back(fallback_location: root_url) && return
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
end
