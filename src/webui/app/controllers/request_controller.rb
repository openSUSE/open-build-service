class RequestController < ApplicationController

  def addreviewer
    @therequest = find_cached(BsRequest, params[:id]) if params[:id]
    BsRequest.free_cache(params[:id])

    begin
      if params[:user]
        r = BsRequest.addReviewByUser( params[:id], params[:user], params[:comment] )
      elsif params[:group]
        r = BsRequest.addReviewByGroup( params[:id], params[:group], params[:comment] )
      else
        render :text => "ERROR: don't know how to add reviewer"
        return
      end
    rescue BsRequest::ModifyError => e
      render :text => e.message
      return
    end
    render :text => "added"
  end

  def modifyreviewer
    @therequest = find_cached(BsRequest, params[:id]) if params[:id]
    BsRequest.free_cache(params[:id])

    begin
      if params[:group].blank?
        r = BsRequest.modifyReviewByUser( params[:id], params[:new_state], params[:comment], session[:login] )
      else
        r = BsRequest.modifyReviewByGroup( params[:id], params[:new_state], params[:comment], params[:group] )
      end

    rescue BsRequest::ModifyError => e
      render :text => e.message
      return
    end
    render :text => params[:new_state]
  end

  def show
    @therequest = BsRequest.find_cached(params[:id]) if params[:id]
    unless @therequest
      flash[:error] = "Can't find request #{params[:id]}"
      redirect_to :action => :index and return
    end

    @id = @therequest.data.attributes["id"]
    @state = @therequest.state.data.attributes["name"]
    @is_author = @therequest.has_element? "//state[@name='new' and @who='#{session[:login]}']"
    @newpackage = []

    @is_reviewer = false
    @req.each_review do |review|
      if review.has_attribute? :by_user
        if review.by_user.to_s == session[:login]
          @is_reviewer = true
          break
        end
      end

      if review.has_attribute? :by_group
        if session[:login]
          user = Person.find_cached(session[:login])
          if user.is_in_group? review.by_group
            @is_reviewer = true
            break
          end
        end
      end
    end

    @revoke_own = (["revoke"].include? params[:changestate]) ? true : false
  
    @is_maintainer = nil
    @therequest.each_action do |action|
      # FIXME: this can't handle multiple actions in a request
      @type = action.data.attributes["type"]
      if @type=="submit"
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
      flash.now[:error] = "Can't get diff for request: #{@diff_error}"
    end

  end
 
  def change_request(changestate, params)
    BsRequest.free_cache( params[:id] )
    begin
      if BsRequest.modify( params[:id], changestate, params[:reason] )
        flash[:note] = "Request #{changestate}!"
        return true
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

end
