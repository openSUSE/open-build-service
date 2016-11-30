require 'base64'

class Webui::RequestController < Webui::WebuiController
  include Webui::HasComments

  helper 'webui/comment'
  helper 'webui/package'

  before_action :require_login, except: [:show, :sourcediff, :diff]
  # requests do not really add much value for our page rank :)
  before_action :lockout_spiders

  before_action :require_request, only: [:changerequest]

  before_action :set_project, only: [:change_devel_request_dialog]

  def add_reviewer_dialog
    @request_number = params[:number]
    render_dialog 'requestAddReviewAutocomplete'
  end

  def add_reviewer
    required_parameters :review_type
    begin
      opts = {}
      case params[:review_type]
        when 'user' then
          opts[:by_user] = params[:review_user]
        when 'group' then
          opts[:by_group] = params[:review_group]
        when 'project' then
          opts[:by_project] = params[:review_project]
        when 'package' then
          opts[:by_project] = params[:review_project]
          opts[:by_package] = params[:review_package]
      end
      opts[:comment] = params[:review_comment] if params[:review_comment]

      req = BsRequest.find_by_number!(params[:number])
      req.addreview(opts)
    rescue BsRequestPermissionCheck::AddReviewNotPermitted
      flash[:error] = "Not permitted to add a review to '#{params[:number]}'"
    rescue ActiveRecord::RecordInvalid, APIException => e
      flash[:error] = "Unable add review to '#{params[:number]}': #{e.message}"
    end
    redirect_to controller: :request, action: 'show', number: params[:number]
  end

  def modify_review
    opts = {}
    state = nil
    req = nil
    params.each do |key, value|
      state = key if  %w(accepted declined new).include? key
      req = BsRequest.find_by_number!(value) if key.starts_with?('review_request_number_')

      # Our views are valid XHTML. So, several forms 'POST'-ing to the same action have different
      # HTML ids. Thus we have to parse 'params' a bit:
      opts[:comment] = value if key.starts_with?('review_comment_')
      opts[:by_user] = value if key.starts_with?('review_by_user_')
      opts[:by_group] = value if key.starts_with?('review_by_group_')
      opts[:by_project] = value if key.starts_with?('review_by_project_')
      opts[:by_package] = value if key.starts_with?('review_by_package_')
    end

    if req.nil?
      flash[:error] = "Unable to load request"
      redirect_back(fallback_location: user_show_path(User.current))
      return
    elsif state.nil?
      flash[:error] = "Unknown state to set"
    else
      begin
        req.permission_check_change_review!(opts)
        req.change_review_state(state, opts)
      rescue BsRequestPermissionCheck::ReviewChangeStateNoPermission => e
        flash[:error] = "Not permitted to change review state: #{e.message}"
      rescue APIException => e
        flash[:error] = "Unable changing review state: #{e.message}"
      end
    end

    redirect_to action: 'show', number: req.number
  end

  def show
    @bsreq = BsRequest.find_by_number(params[:number])
    unless @bsreq
      flash[:error] = "Can't find request #{params[:number]}"
      redirect_back(fallback_location: user_show_path(User.current)) && return
    end

    @req = @bsreq.webui_infos
    @id = @req['id']
    @number = @req['number']
    @state = @req['state'].to_s
    @accept_at = @req['accept_at']
    @is_author = @req['creator'] == User.current
    @superseded_by = @req['superseded_by']
    @superseding = @req['superseding']
    @is_target_maintainer = @req['is_target_maintainer']

    @my_open_reviews = @req['my_open_reviews']
    @other_open_reviews = @req['other_open_reviews']
    # rubocop:disable Metrics/LineLength
    @can_add_reviews = %w(new review).include?(@state) && (@is_author || @is_target_maintainer || @my_open_reviews.length > 0) && !User.current.is_nobody?
    # rubocop:enable Metrics/LineLength
    @can_handle_request = %w(new review declined).include?(@state) && (@is_target_maintainer || @is_author) && !User.current.is_nobody?

    @history = History.find_by_request(@bsreq, {withreviews: 1})
    @actions = @req['actions']

    # retrieve a list of all package maintainers that are assigned to at least one target package
    @package_maintainers = get_target_package_maintainers(@actions) || []

    # search for a project, where the user is not a package maintainer but a project maintainer and show
    # a hint if that package has some package maintainers (issue#1970)
    projects = @actions.map{|action| action[:tprj]}.uniq
    maintainer_role = Role.find_by_title("maintainer")

    @show_project_maintainer_hint = (!@package_maintainers.empty? && !@package_maintainers.include?(User.current) &&
      projects.any? { |project| Project.find_by_name(project).user_has_role?(User.current, maintainer_role) })

    @request_before = nil
    @request_after = nil
    index = session[:request_numbers].try(:index, @number)
    if index
      @request_before = session[:request_numbers][index-1] if index > 0
      # will be nil for after end
      @request_after = session[:request_numbers][index+1]
    end

    @comments = @bsreq.comments
  end

  def package_maintainers_dialog
    @maintainers = get_target_package_maintainers(params[:actions])
    render_dialog unless @maintainers.empty?
  end

  def sourcediff
    check_ajax
    render partial: 'shared/editor', locals: {text: params[:text],
                                                    mode: 'diff', read_only: true,
                                                    height: 'auto', width: '750px',
                                                    no_border: true, uid: params[:uid]}
  end

  def require_request
    required_parameters :number
    @req = BsRequest.find_by_number params[:number]
    unless @req
      flash[:error] = "Can't find request #{params[:number]}"
      redirect_back(fallback_location: user_show_path(User.current)) && return
    end
  end

  def changerequest
    @req = BsRequest.find_by_number(params[:number])
    unless @req
      flash[:error] = "Can't find request #{params[:number]}"
      redirect_back(fallback_location: user_show_path(User.current)) && return
    end

    changestate = nil
    %w(accepted declined revoked new).each do |s|
      if params.has_key? s
        changestate = s
        break
      end
    end

    if change_state(changestate, params)
      # TODO: Make this work for each submit action individually
      if params[:add_submitter_as_maintainer_0]
        if changestate != 'accepted'
          flash[:error] = 'Will not add maintainer for not accepted requests'
        else
          tprj, tpkg = params[:add_submitter_as_maintainer_0].split('_#_') # split into project and package
          if tpkg
            target = Package.find_by_project_and_name(tprj, tpkg)
          else
            target = Project.find_by_name tprj
          end
          if target.check_write_access
            # the request action type might be permitted in future, but that doesn't mean we
            # are allowed to modify the object
            target.add_user(@req.creator, 'maintainer')
            target.save
            target.store if target.kind_of? Project
          end
        end
      end

      accept_request if changestate == 'accepted'
    end

    redirect_to action: 'show', number: params[:number]
  end

  def accept_request
    flash[:notice] = "Request #{params[:number]} accepted"

    # Check if we have to forward this request to other projects / packages
    params.keys.grep(/^forward_.*/).each do |fwd|
      forward_request_to(fwd)
    end
  end

  def forward_request_to(fwd)
    tgt_prj, tgt_pkg = params[fwd].split('_#_') # split off 'forward_' and split into project and package

    req = nil
    begin
      BsRequest.transaction do
        req = BsRequest.new( state: "new")
        req.description = params[:description]
        @req.bs_request_actions.each do |action|
          rev = Directory.hashed(project: action.target_project, package: action.target_package)['rev']

          opts = { source_project: action.target_project,
                   source_package: action.target_package,
                   source_rev:     rev,
                   target_project: tgt_prj,
                   target_package: tgt_pkg }
          if params[:sourceupdate]
            opts[:sourceupdate] = params[:sourceupdate]
          end
          action = BsRequestActionSubmit.new(opts)
          req.bs_request_actions << action
          action.bs_request = req

          req.save!
        end
      end
    rescue APIException => e
      HoptoadNotifier.notify(e, { failed_job: "Failed to forward BsRequest '#{params[:number]}'" })
      flash[:error] = "Unable to forward submit: #{e.message}"
      redirect_to(request_show_path(params[:number])) && return
    end

    target_link = ActionController::Base.helpers.link_to("#{tgt_prj} / #{tgt_pkg}", package_show_url(project: tgt_prj, package: tgt_pkg))
    request_link = ActionController::Base.helpers.link_to(req.number, request_show_path(req.number))
    flash[:notice] += " and forwarded to #{target_link} (request #{request_link})"
  end

  def diff
    # just for compatibility. OBS 1.X used this route for show
    redirect_to action: :show, number: params[:number]
  end

  def list
    redirect_to(user_show_path(User.current)) && return unless request.xhr? # non ajax request
    requests = BsRequest.list_ids(params)
    elide_len = (params[:elide_len] || 44).to_i
    session[:request_numbers] = requests.map { |id| BsRequest.find(id).number }.uniq
    requests = BsRequest.collection(ids: requests)
    render partial: 'shared/requests', locals: {requests: requests, elide_len: elide_len, no_target: params[:no_target]}
  end

  def list_small
    required_parameters :project # the minimum
    redirect_to(user_show_path(User.current)) && return unless request.xhr? # non ajax request
    requests = BsRequest.list_ids(params)
    requests = BsRequest.collection(ids: requests)
    render partial: 'requests_small', locals: {requests: requests}
  end

  def delete_request_dialog
    @project = params[:project]
    @package = params[:package] if params[:package]
    render_dialog
  end

  def delete_request
    required_parameters :project
    req = nil
    begin
      BsRequest.transaction do
        req = BsRequest.new
        req.state = "new"
        req.description = params[:description]

        opts = {target_project: params[:project]}
        opts[:target_package] = params[:package] if params[:package]
        opts[:target_repository] = params[:repository] if params[:repository]
        action = BsRequestActionDelete.new(opts)
        req.bs_request_actions << action
        action.bs_request = req

        req.save!
      end

      request_link = ActionController::Base.helpers.link_to("repository delete request #{req.number}", request_show_path(req.number))
      flash[:success] = "Created #{request_link}"

    rescue APIException => e
      flash[:error] = e.message
      if params[:package]
        redirect_to package_show_path(project: params[:project], package: params[:package])
      else
        redirect_to project_show_path(project: params[:project])
      end
      return
    end
    redirect_to request_show_path(number: req.number)
  end

  def add_role_request_dialog
    @project = params[:project]
    @package = params[:package] if params[:package]
    render_dialog
  end

  def add_role_request
    required_parameters :project, :role
    req=nil
    begin
      BsRequest.transaction do
        req = BsRequest.new
        req.state = "new"
        req.description = params[:description]

        opts = { target_project: params[:project],
                 role:           params[:role]
               }
        opts[:target_package] = params[:package] if params[:package]
        opts[:person_name] = params[:user] if params[:user]
        opts[:group_name] = params[:group] if params[:group]
        action = BsRequestActionAddRole.new(opts)
        req.bs_request_actions << action
        action.bs_request = req

        req.save!
      end
    rescue APIException => e
      flash[:error] = e.message
      redirect_to(controller: :package, action: :show, package: params[:package], project: params[:project]) && return if params[:package]
      redirect_to(controller: :project, action: :show, project: params[:project]) && return
    end
    redirect_to controller: :request, action: :show, number: req.number
  end

  def set_bugowner_request_dialog
    render_dialog
  end

  def set_bugowner_request
    required_parameters :project, :user, :group
    req=nil
    begin
      BsRequest.transaction do
        req = BsRequest.new
        req.state = "new"
        req.description = params[:description]

        opts = {target_project: params[:project]}
        opts[:target_package] = params[:package] if params[:package]
        opts[:person_name] = params[:user] if params[:user]
        opts[:group_name] = params[:group] if params[:group]
        action = BsRequestActionSetBugowner.new(opts)
        req.bs_request_actions << action
        action.bs_request = req

        req.save!
      end
    rescue APIException => e
      flash[:error] = e.message
      redirect_to(controller: :package, action: :show, package: params[:package], project: params[:project]) && return if params[:package]
      redirect_to(controller: :project, action: :show, project: params[:project]) && return
    end
    redirect_to controller: :request, action: :show, number: req.number
  end

  def change_devel_request_dialog
    required_parameters :package, :project
    @package = Package.find_by_project_and_name(params[:project], params[:package])
    if @package.develpackage
      @current_devel_package = @package.develpackage.name
      @current_devel_project = @package.develpackage.project.name
    end
    render_dialog
  end

  def change_devel_request
    required_parameters :devel_project, :package, :project
    req = nil
    begin
      BsRequest.transaction do
        req = BsRequest.new(state: "new", description: params[:description])
        action = BsRequestActionChangeDevel.new({
          target_project: params[:project],
          target_package: params[:package],
          source_project: params[:devel_project],
          source_package: params[:devel_package] || params[:package]
        })

        req.bs_request_actions << action
        action.bs_request = req
        req.save!
      end
    rescue BsRequestAction::UnknownProject,
           Package::UnknownObjectError,
           BsRequestAction::UnknownTargetPackage => e
      flash[:error] = "No such package: #{e.message}"
      redirect_to package_show_path(project: params[:project], package: params[:package])
      return
    rescue APIException => e
      flash[:error] = "Unable to create request: #{e.message}"
      redirect_to package_show_path(project: params[:project], package: params[:package])
      return
    end
    redirect_to request_show_path(number: req.number)
  end

  def set_incident_dialog
    render_dialog
  end

  def set_incident
    req = BsRequest.find_by_number(params[:number])
    if req.nil?
      flash[:error] = "Unable to load request"
    elsif params[:incident_project].blank?
      flash[:error] = "Unknown incident project to set"
    else
      begin
        req.setincident(params[:incident_project])
        flash[:notice] = "Set target of request #{req.number} to incident #{params[:incident_project]}"
      rescue Project::UnknownObjectError => e
        flash[:error] = "Incident #{e.message} does not exist"
      rescue APIException => e
        flash[:error] = "Not able to set incident: #{e.message}"
      end
    end

    redirect_to action: 'show', number: params[:number]
  end

  # used by mixins
  def main_object
    BsRequest.find_by_number params[:number]
  end

  private

  def get_target_package_maintainers(actions)
    actions = actions.uniq{ |action| action[:tpkg] }
    actions.flat_map { |action| Package.find_by_project_and_name(action[:tprj], action[:tpkg]).try(:maintainers) }.compact.uniq
  end

  def change_state(newstate, params)
    req = BsRequest.find_by_number(params[:number])
    if req.nil?
      flash[:error] = "Unable to load request"
    else
      # FIXME: make force optional, it hides warnings!
      opts = {
        newstate: newstate,
        force:    true,
        user:     User.current.login,
        comment:  params[:reason]
      }
      begin
        req.change_state(opts)
        flash[:notice] = "Request #{newstate}!"
        return true
      rescue APIException => e
        flash[:error] = "Failed to change state: #{e.message}!"
        return false
      end
    end

    false
  end
end
