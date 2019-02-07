class Webui::RequestController < Webui::WebuiController
  helper 'webui/package'

  before_action :require_login, except: [:show, :sourcediff, :diff]
  # requests do not really add much value for our page rank :)
  before_action :lockout_spiders

  before_action :require_request, only: [:changerequest, :show]

  before_action :set_project, only: [:change_devel_request_dialog]

  before_action :set_superseded_request, only: :show

  before_action :check_ajax, only: :sourcediff

  def add_reviewer_dialog
    @request_number = params[:number]
    render_dialog('requestAddReviewAutocomplete')
  end

  def add_reviewer
    begin
      opts = {}
      # bento_only
      # user, group, project, package are bento only
      # and should be removed as soon the Bootstrap
      # migration is finished
      case params[:review_type]
      when 'review-user', 'user'
        opts[:by_user] = params[:review_user]
      when 'review-group', 'group'
        opts[:by_group] = params[:review_group]
      when 'review-project', 'project'
        opts[:by_project] = params[:review_project]
      when 'review-package', 'package'
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

  def modify_review
    review_params = params.slice(:comment, :by_user, :by_group, :by_project, :by_package)
    request = BsRequest.find_by_number(params[:request_number])

    if request.nil?
      flash[:error] = 'Unable to load request'
      redirect_back(fallback_location: user_show_path(User.current))
      return
    elsif !new_state.in?(['accepted', 'declined'])
      flash[:error] = 'Unknown state to set'
    else
      begin
        request.permission_check_change_review!(review_params)
        request.change_review_state(new_state, review_params)
      rescue BsRequestPermissionCheck::ReviewChangeStateNoPermission => e
        flash[:error] = "Not permitted to change review state: #{e.message}"
      rescue APIError => e
        flash[:error] = "Unable changing review state: #{e.message}"
      end
    end

    redirect_to request_show_path(number: request), success: 'Successfully submitted review'
  end

  def show
    diff_limit = params[:full_diff] ? 0 : nil

    @request_webui_info = ::RequestControllerService::RequestForWebuiFetcher.call(@bs_request, diff_limit,
                                                                                  @diff_to_superseded, User.current)

    @comments = @bs_request.comments
    @comment = Comment.new

    # TODO: Remove the statement after migration is finished
    switch_to_webui2 if Rails.env.development? || Rails.env.test?
  end

  def sourcediff
    render partial: 'shared/editor', locals: { text: params[:text],
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
          target.add_maintainer(@bs_request.creator) if target.can_be_modified_by?(User.current)
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
    redirect_to(user_show_path(User.current)) && return unless request.xhr? # non ajax request
    requests = BsRequest.list(params)
    switch_to_webui2
    render partial: 'requests_small', locals: { requests: requests }
  end

  def delete_request_dialog
    @project = params[:project]
    @package = params[:package] if params[:package]
    render_dialog
  end

  def delete_request
    request = nil
    begin
      request = BsRequest.create!(
        description: params[:description], bs_request_actions: [BsRequestAction.new(request_action_attributes(:delete))]
      )
      request_link = ActionController::Base.helpers.link_to("delete request #{request.number}", request_show_path(request.number))
      flash[:success] = "Created #{request_link}"
    rescue APIError => e
      flash[:error] = e.message
      if params[:package]
        redirect_to package_show_path(project: params[:project], package: params[:package])
      else
        redirect_to project_show_path(project: params[:project])
      end
      return
    end
    redirect_to request_show_path(number: request.number)
  end

  def add_role_request_dialog
    @project = params[:project]
    @package = params[:package] if params[:package]
    render_dialog
  end

  def add_role_request
    request = nil
    begin
      request = BsRequest.create!(
        description: params[:description], bs_request_actions: [BsRequestAction.new(request_action_attributes(:add_role))]
      )
    rescue APIError => e
      flash[:error] = e.message
      redirect_to(controller: :package, action: :show, package: params[:package], project: params[:project]) && return if params[:package]
      redirect_to(controller: :project, action: :show, project: params[:project]) && return
    end
    redirect_to controller: :request, action: :show, number: request.number
  end

  def set_bugowner_request_dialog
    render_dialog
  end

  def set_bugowner_request
    required_parameters :project, :user, :group
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

  # TODO: This action needs to be removed when migrating to Bootstrap, is not needed in the webui2
  def change_devel_request_dialog
    @package = Package.find_by_project_and_name(params[:project], params[:package])
    if @package.develpackage
      @current_devel_package = @package.develpackage.name
      @current_devel_project = @package.develpackage.project.name
    end

    render_dialog
  end

  def change_devel_request
    request = nil
    begin
      request = BsRequest.create!(
        description: params[:description], bs_request_actions: [BsRequestAction.new(request_action_attributes(:change_devel))]
      )
    rescue BsRequestAction::UnknownProject,
           Package::UnknownObjectError,
           BsRequestAction::UnknownTargetPackage => e
      flash[:error] = "No such package: #{e.message}"
      redirect_to package_show_path(project: params[:project], package: params[:package])
      return
    rescue APIError => e
      flash[:error] = "Unable to create request: #{e.message}"
      redirect_to package_show_path(project: params[:project], package: params[:package])
      return
    end
    redirect_to request_show_path(number: request.number)
  end

  def set_incident_dialog
    render_dialog
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
        flash[:notice] = "Set target of request #{request.number} to incident #{params[:incident_project]}"
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
    return
  end

  def require_request
    required_parameters :number
    @bs_request = BsRequest.find_by_number(params[:number])
    return if @bs_request
    flash[:error] = "Can't find request #{params[:number]}"
    redirect_back(fallback_location: user_show_path(User.current)) && return
  end

  def get_target_package_maintainers(actions)
    actions = actions.uniq { |action| action[:tpkg] }
    actions.flat_map { |action| Package.find_by_project_and_name(action[:tprj], action[:tpkg]).try(:maintainers) }.compact.uniq
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
        user: User.current.login,
        comment: params[:reason]
      }
      begin
        request.change_state(opts)
        flash[:notice] = "Request #{newstate}!"
        return true
      rescue APIError => e
        flash[:error] = "Failed to change state: #{e.message}!"
        return false
      end
    end

    false
  end

  def accept_request
    flash[:notice] = "Request #{params[:number]} accepted"

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
    request_link = ActionController::Base.helpers.link_to(forwarded_request.number, request_show_path(forwarded_request.number))
    flash[:notice] += " and forwarded to #{target_link} (request #{request_link})"
  end

  def request_action_attributes(type)
    {
      target_project: params[:project],
      target_package: params[:package],
      source_project: params[:devel_project],
      source_package: params[:devel_package] || params[:package],
      target_repository: params[:repository],
      person_name: params[:user],
      group_name: params[:group],
      role: params[:role],
      type: type.to_s
    }
  end
end
