require 'base64'

class Webui::RequestController < Webui::WebuiController
  include Webui::WebuiHelper
  include Webui::HasComments

  helper 'webui/comment'
  helper 'webui/package'

  before_filter :require_login, :only => [:save_comment]
  # requests do not really add much value for our page rank :)
  before_filter :lockout_spiders

  before_filter :require_request, only: [:changerequest]

  def add_reviewer_dialog
    @request_id = params[:id]
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

      req = BsRequest.find_by_id(params[:id])
      req.addreview(opts)
    rescue BsRequestPermissionCheck::AddReviewNotPermitted
      flash[:error] = "Not permitted to add a review to '#{params[:id]}'"
    rescue APIException => e
      flash[:error] = "Unable add review to '#{params[:id]}': #{e.message}"
    end
    redirect_to :controller => :request, :action => 'show', :id => params[:id]
  end

  def modify_review
    opts = {}
    state = nil
    req = nil
    params.each do |key, value|
      state = key if  %w(accepted declined new).include? key
      req = BsRequest.find_by_id(value) if key.starts_with?('review_request_id_')

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
      redirect_back_or_to user_requests_path(User.current)
      return
    elsif state.nil?
      flash[:error] = "Unknown state to set"
    else
      begin
        req.permission_check_change_review!(opts)
        req.change_review_state(state, opts)
      rescue BsRequestPermissionCheck::ReviewChangeStateNoPermission
        flash[:error] = "Not permitted to change review state: #{e.message}"
      rescue APIException => e
        flash[:error] = "Unable changing review state: #{e.message}"
      end
    end

    redirect_to :action => 'show', :id => req.id
  end

  def show
    redirect_back_or_to user_requests_path(User.current) and return if !params[:id]
    begin
      @bsreq = BsRequest.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "Can't find request #{params[:id]}"
      redirect_back_or_to user_requests_path(User.current) and return
    end

    @req = @bsreq.webui_infos
    @id = @req['id']
    @state = @req['state'].to_s
    @accept_at = @req['accept_at']
    @is_author = @req['creator'] == User.current
    @superseded_by = @req['superseded_by']
    @superseding = @req['superseding']
    @is_target_maintainer = @req['is_target_maintainer']

    @my_open_reviews = @req['my_open_reviews']
    @other_open_reviews = @req['other_open_reviews']
    @can_add_reviews = %w(new review).include?(@state) && (@is_author || @is_target_maintainer || @my_open_reviews.length > 0) && !User.current.is_nobody?
    @can_handle_request = %w(new review declined).include?(@state) && (@is_target_maintainer || @is_author) && !User.current.is_nobody?

    @history = History.find_by_request(@bsreq, {withreviews: 1})
    @actions = @req['actions']

    request_list = session[:requests]
    @request_before = nil
    @request_after = nil
    index = request_list.index(@id) if request_list
    if index and index > 0
      @request_before = request_list[index-1]
    end
    if index
      # will be nul for after end
      @request_after = request_list[index+1]
    end

    sort_comments(BsRequest.find(params[:id]).comments)
  end

  def sourcediff
    check_ajax
    render :partial => 'shared/editor', :locals => {:text => params[:text], :mode => 'diff', :read_only => true, :height => 'auto', :width => '750px', :no_border => true, uid: params[:uid]}
  end

  def require_request
    required_parameters :id
    @req = BsRequest.find params[:id]
    unless @req
      flash[:error] = "Can't find request #{params[:id]}"
      redirect_back_or_to user_requests_path(User.current) and return
    end
  end

  def changerequest
    begin
      @req = BsRequest.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "Can't find request #{params[:id]}"
      redirect_back_or_to user_requests_path(User.current) and return
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
            target = Project.Project.find_by_name tprj
          end
          target.add_user(@req.creator, 'maintainer')
          target.save
        end
      end
    end

    accept_request if changestate == 'accepted'

    redirect_to :action => 'show', :id => params[:id]
  end

  def accept_request
    flash[:notice] = "Request #{params[:id]} accepted"

    # Check if we have to forward this request to other projects / packages
    params.keys.grep(/^forward_.*/).each do |fwd|
      forward_request_to(fwd)
    end
  end

  def forward_request_to(fwd)
    tgt_prj, tgt_pkg = params[fwd].split('_#_') # split off 'forward_' and split into project and package
    description = @req.description
    who = @req.creator
    description += ' (forwarded request %d from %s)' % [params[:id], who]

    req = nil
    begin
      BsRequest.transaction do
        req = BsRequest.new( state: "new")
        req.description = params[:description]
        @req.bs_request_actions.each do |action|
          rev = Package.dir_hash(action.target_project, action.target_package)['rev']

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
      flash[:error] = "Unable to forward submit: #{e.message}"
      redirect_to(:action => 'show', :project => params[:project], :package => params[:package]) and return
    end


    # link_to isn't available here, so we have to write some HTML. Uses url_for to not hardcode URLs.
    flash[:notice] += " and forwarded to <a href='#{url_for(:controller => 'package', :action => 'show', :project => tgt_prj, :package => tgt_pkg)}'>#{tgt_prj} / #{tgt_pkg}</a> (request <a href='#{url_for(:action => 'show', :id => req.id)}'>#{req.id}</a>)"
  end

  def diff
    # just for compatibility. OBS 1.X used this route for show
    redirect_to :action => :show, :id => params[:id]
  end

  def list
    redirect_to user_requests_path(User.current) and return unless request.xhr? # non ajax request
    requests = BsRequestCollection.list_ids(params)
    elide_len = 44
    elide_len = params[:elide_len].to_i if params[:elide_len]
    session[:requests] = requests
    requests = BsRequestCollection.new(ids: session[:requests]).relation
    render :partial => 'shared/requests', :locals => {:requests => requests, :elide_len => elide_len, :no_target => params[:no_target]}
  end

  def list_small
    required_parameters :project # the minimum
    redirect_to user_requests_path(User.current) and return unless request.xhr? # non ajax request
    requests = BsRequestCollection.list_ids(params)
    requests = BsRequestCollection.new(ids: requests).relation
    render partial: 'requests_small', locals: {requests: requests}
  end

  def delete_request_dialog
    @project = params[:project]
    @package = params[:package] if params[:package]
    render_dialog
  end

  def delete_request
    required_parameters :project
    req=nil
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
      flash[:success] = "Created <a href='#{url_for(:controller => 'request', :action => 'show', :id => req.id)}'>repository delete request #{req.id}</a>"
    rescue APIException => e
      flash[:error] = e.message
      redirect_to :controller => :package, :action => :show, :package => params[:package], :project => params[:project] and return if params[:package]
      redirect_to :controller => :project, :action => :show, :project => params[:project] and return
    end
    redirect_to :controller => :request, :action => :show, :id => req.id
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

        opts = {target_project: params[:project],
                role: params[:role]}
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
      redirect_to :controller => :package, :action => :show, :package => params[:package], :project => params[:project] and return if params[:package]
      redirect_to :controller => :project, :action => :show, :project => params[:project] and return
    end
    redirect_to :controller => :request, :action => :show, :id => req.id
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
      redirect_to :controller => :package, :action => :show, :package => params[:package], :project => params[:project] and return if params[:package]
      redirect_to :controller => :project, :action => :show, :project => params[:project] and return
    end
    redirect_to :controller => :request, :action => :show, :id => req.id
  end

  def change_devel_request_dialog
    required_parameters :package, :project
    @project = WebuiProject.find params[:project]
    @package = Package.find_by_project_and_name(params[:project], params[:package])
    if @package.develpackage
      @current_devel_package = @package.develpackage.name
      @current_devel_project = @package.develpackage.project.name
    end
    render_dialog
  end

  def change_devel_request
    required_parameters :devel_project, :package, :project
    req=nil
    begin
      BsRequest.transaction do
        req = BsRequest.new
        req.state = "new"
        req.description = params[:description]

        opts = {target_project: params[:project],
                target_package: params[:package],
                source_project: params[:devel_project],
                source_package: params[:devel_package] || params[:package]}
        action = BsRequestActionChangeDevel.new(opts)
        req.bs_request_actions << action
        action.bs_request = req

        req.save!
      end
    rescue BsRequestAction::UnknownProject,
           Package::UnknownObjectError,
           Package::ReadAccessError,
           BsRequestAction::UnknownTargetPackage => e
      flash[:error] = "No such package: #{e.message}"
      redirect_to :controller => 'package', :action => 'show', :project => params[:project], :package => params[:package] and return
    rescue APIException => e
      flash[:error] = "Unable to create request: #{e.message}"
      redirect_to :controller => 'package', :action => 'show', :project => params[:project], :package => params[:package] and return
    end
    redirect_to :controller => 'request', :action => 'show', id: req.id
  end

  def set_incident_dialog
    render_dialog
  end

  def set_incident
    req = BsRequest.find_by_id(params[:id])
    if req.nil?
      flash[:error] = "Unable to load request"
    elsif params[:incident_project].blank?
      flash[:error] = "Unknown incident project to set"
    else
      begin
        req.permission_check_setincident!(params[:incident_project])
        req.setincident(params[:incident_project])
        flash[:notice] = "Set target of request #{req.id} to incident #{params[:incident_project]}"
      rescue Project::UnknownObjectError => e
        flash[:error] = "Incident #{e.message} does not exist"
      rescue APIExcetion => e
        flash[:error] = "Not able to set incident: #{e.message}"
      end
    end

    redirect_to :action => 'show', :id => params[:id]
  end

  # used by mixins
  def main_object
    BsRequest.find params[:id]
  end

  private

  def change_state(newstate, params)
    req = BsRequest.find_by_id(params[:id])
    if req.nil?
      flash[:error] = "Unable to load request"
    else
      # FIXME: make force optional, it hides warnings!
      opts = { :newstate=>newstate,
               :force => true,
               :user => User.current.login,
               :comment => params[:reason] }
      begin
        req.change_state(opts)
        flash[:notice] = "Request #{newstate}!"
        return true
      rescue APIException => e
        flash[:error] = "Failed to change state: #{e.message}!"
        return false
      end
    end

    return false
  end

end
