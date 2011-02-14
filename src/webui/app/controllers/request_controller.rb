class RequestController < ApplicationController

  def addreviewer
    @therequest = find_cached(BsRequest, params[:request_id]) if params[:request_id]
    BsRequest.free_cache(params[:request_id])

    begin
      opts = {}
      case params[:review_type]
        when "user" then opts[:user] = params[:review_name]
        when "group" then opts[:group] = params[:review_name]
        when "project" then opts[:project] = params[:review_name]
        when "package" then opts[:project] = params[:review_name]
                            opts[:package] = params[:review_package]
      end
      opts[:comment] = params[:review_comment] if params[:review_comment]

      BsRequest.addReview(params[:request_id], opts)
    rescue BsRequest::ModifyError => e
      flash[:error] = e.message
    end
    redirect_to :action => "show", :id => params[:request_id] and return
  end

  def modifyreviewer
    @therequest = find_cached(BsRequest, params[:id]) if params[:id]
    BsRequest.free_cache(params[:id])

    begin
      BsRequest.modifyReview(params[:id], params[:new_state], params)
      render :text => params[:new_state]
    rescue BsRequest::ModifyError => e
      render :text => e.message
    end
  end

  def show
    @req = BsRequest.find_cached(params[:id]) if params[:id]
    unless @req
      flash[:error] = "Can't find request #{params[:id]}"
      redirect_to :action => :index and return
    end

    @id = @req.data.attributes["id"]
    @state = @req.state.data.attributes["name"]
    # FIXME: actually also the history should be checked here
    @is_author = @req.has_element? "//state[@name='new' and @who='#{session[:login]}']" 
    @is_author = @req.has_element? "//state[@name='review' and @who='#{session[:login]}']" unless @is_author
    @superseded_by = @req.state.data.attributes["superseded_by"] if @req.state.has_attribute? :superseded_by and not @req.state.data.attributes["superseded_by"].empty?
    @newpackage = []

    @is_reviewer = false
    @req.each_review do |review|
      if review.has_attribute? :by_user
        if review.by_user.to_s == session[:login]
          @is_reviewer = true
          break
        end
      end

      if session[:login]
        user = Person.find_cached(session[:login])
        if (review.has_attribute? :by_group and user.is_in_group? review.by_group) or
           (review.has_attribute? :by_project and user.is_maintainer? review.by_project) or
           (review.has_attribute? :by_project and user.is_maintainer? review.by_project and revoke.has_attribute? :by_package and user.is_maintainer? review.by_package)
          @is_reviewer = true and break
        end
      end
    end

    @revoke_own = (["revoke"].include? params[:changestate]) ? true : false
  
    @is_maintainer = nil
    @req.each_action do |action|
      if action.data.attributes["type"] == "submit"
        @src_project = action.source.project
        @src_pkg = action.source.package
      end
      @target_project = find_cached(Project, action.target.project, :expires_in => 5.minutes)
      @target_pkg_name = action.target.value :package
      @target_pkg = find_cached(Package, @target_pkg_name, :project => action.target.project) if @target_pkg_name
      if @is_maintainer == nil or @is_maintainer == true
        @is_maintainer = @target_project && @target_project.can_edit?( session[:login] )
        if @target_pkg
          @is_maintainer = @is_maintainer || @target_pkg.can_edit?( session[:login] )
        else
          @newpackage << { :project => action.target.project, :package => @target_pkg_name }
        end
      end
    end

    # get the entire diff from the api
    begin
      transport ||= ActiveXML::Config::transport_for :bsrequest
      @diff_text = transport.direct_http URI("/request/#{@id}?cmd=diff"), :method => "POST", :data => ""
    rescue ActiveXML::Transport::Error => e
      @diff_error, code, api_exception = ActiveXML::Transport.extract_error_message e
      logger.debug "Can't get diff for request: #{@diff_error}"
    end
  end
 
  def change_request(changestate, params)
    BsRequest.free_cache( params[:id] )
    begin
      if BsRequest.modify( params[:id], changestate, params[:reason] )
        flash[:note] = "Request #{changestate}!" and return true
      else
        flash[:error] = "Can't change request to #{changestate}!"
      end
    rescue BsRequest::ModifyError => e
      flash[:error] = e.message
    end
    return false
  end
  private :change_request


  def changerequest
    @therequest = find_cached(BsRequest, params[:id] ) if params[:id]
    unless @therequest
      flash[:error] = "Can't find request #{params[:id]}"
      redirect_to :action => :index and return
    end

    changestate = nil
    %w{forward accepted declined revoked}.each do |s|
      if params.has_key? s
        changestate = s
        break
      end
    end

    if changestate == 'forward' # special case
      description = @therequest.description.text
      logger.debug 'request ' +  @therequest.dump_xml

      if @therequest.has_element? 'state'
        who = @therequest.state.data["who"].to_s
        description += " (forwarded request %d from %s)" % [params[:id], who]
      end

      if not change_request('accepted', params)
        redirect_to :action => :show, :id => params[:id]
        return
      end

      rev = Package.current_rev(@therequest.action.target.project, @therequest.action.target.package)
      @therequest = BsRequest.new(:type => "submit", :targetproject => params[:forward_project], :targetpackage => params[:forward_package],
        :project => @therequest.action.target.project, :package => @therequest.action.target.package, :rev => rev, :description => description)
      @therequest.save(:create => true)
      Rails.cache.delete "requests_new"
      flash[:note] = "Request #{params[id]} accepted and forwarded"
      redirect_to :controller => :request, :action => :show, :id => @therequest.data["id"]
      return
    end

    change_request(changestate, params)
    Directory.free_cache( :project => @therequest.action.target.project, :package => @therequest.action.target.value('package') )
    redirect_to :action => :show, :id => params[:id]
  end

  def diff
    # just for compatibility. OBS 1.X used this route for show
    redirect_to :action => :show, :id => params[:id]
  end

  def list
    redirect_to :controller => :home, :action => :list_requests and return unless request.xhr?  # non ajax request
    requests = BsRequest.list(params)
    render :partial => 'shared/list_requests', :locals => {:requests => requests, :elide_len => params[:elide_len].to_i ||= 44}
  end

  def delete_request_dialog
    @project = params[:project]
    @package = params[:package] if params[:package]
  end

  def delete_request
    begin
      req = BsRequest.new(:type => "delete", :targetproject => params[:project], :targetpackage => params[:package])
      req.save(:create => true)
    rescue ActiveXML::Transport::NotFoundError => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
      redirect_to :controller => :package, :action => :show, :package => params[:package], :project => params[:project] and return if params[:package]
      redirect_to :controller => :project, :action => :show, :project => params[:project] and return
    end
    Rails.cache.delete "requests_new"
    redirect_to :controller => :request, :action => :show, :id => req.data["id"]
  end

  def add_role_request_dialog
    @project = params[:project]
    @package = params[:package] if params[:package]
  end

  def add_role_request
    begin
      req = BsRequest.new(:type => "add_role", :targetproject => params[:project], :targetpackage => params[:package], :role => params[:role], :person => params[:user])
      req.save(:create => true)
    rescue ActiveXML::Transport::NotFoundError => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
      redirect_to :controller => :package, :action => :show, :package => params[:package], :project => params[:project] and return if params[:package]
      redirect_to :controller => :project, :action => :show, :project => params[:project] and return
    end
    Rails.cache.delete "requests_new"
    redirect_to :controller => :request, :action => :show, :id => req.data["id"]
  end
end
