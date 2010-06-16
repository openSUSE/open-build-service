class RequestController < ApplicationController

  def show
    if params[:id]
      @therequest = find_cached(Request, params[:id] )
    end
    unless @therequest
      flash[:error] = "Can't find request #{params[:id]}"
      redirect_to :action => :index and return
    end

    @id = @therequest.data.attributes["id"]
    @state = @therequest.state.data.attributes["name"]
    @is_author = @therequest.has_element? "//state[@name='new' and @who='#{session[:login]}']"
    @newpackage = []

    @therequest.each_action do |action|
      @type = action.data.attributes["type"]
      if @type=="submit"
        @src_project = action.source.project
        @src_pkg = action.source.package
      end
      @target_project = find_cached(Project, action.target.project, :expires_in => 5.minutes)
      @target_pkg_name = action.target.value :package
      @target_pkg = find_cached(Package, @target_pkg_name, :project => action.target.project) if @target_pkg_name
      @is_maintainer = @target_project.is_maintainer?( session[:login] ) ||
        (@target_pkg && @target_pkg.is_maintainer?( session[:login] ))

      if @type == "submit" and @target_pkg
        transport = ActiveXML::Config::transport_for(:request)
        path = "/source/%s/%s?opackage=%s&oproject=%s&cmd=diff&expand=1" %
        [CGI.escape(@src_project), CGI.escape(@src_pkg), CGI.escape(@target_pkg.name), CGI.escape(@target_project.name)]
        if action.source.data['rev']
          path += "&rev=#{action.source.rev}"
        end
        begin
          @diff_text = transport.direct_http URI("https://#{path}"), :method => "POST", :data => ""
        rescue ActiveXML::Transport::Error => e
          @diff_error, code, api_exception = ActiveXML::Transport.extract_error_message e
          flash.now[:error] = "Can't get diff for request: #{@diff_error}"
        end
      elsif @type == "submit" and @target_pkg.nil?
        @newpackage << { :package => @src_pkg, :project => @src_project }
      end
    end

    @revoke_own = (["revoke"].include? params[:changestate]) ? true : false
  
  end
 
  def change_request(changestate, params)
    Request.free_cache( params[:id] )
    begin
      if Request.modify( params[:id], changestate, params[:reason] )
        flash[:note] = "Request #{changestate}!"
        return true
      else
        flash[:error] = "Can't change request to #{changestate}!"
      end
    rescue Request::ModifyError => e
      flash[:error] = e.message
    end
    return false
  end
  private :change_request


  def submitreq
    changestate = nil
    %w{forward accepted declined revoked}.each do |s|
      if params.has_key? s
        changestate = s
        break
      end
    end

    req = find_cached(Request, params[:id] )
    if changestate == 'forward' # special case
      description = req.description.text
      logger.debug 'request ' +  req.dump_xml

      if req.has_element? 'state'
        who = req.state.data["who"].to_s
        description += " (forwarded request %d from %s)" % [params[:id], who]
      end

      if not change_request('accepted', params)
        redirect_to :action => :show, :id => params[:id]
        return
      end

      rev = Package.current_rev(req.action.target.project, req.action.target.package)
      req = Request.new(:type => "submit", :targetproject => params[:forward_project], :targetpackage => params[:forward_package],
        :project => req.action.target.project, :package => req.action.target.package, :rev => rev, :description => description)
      req.save(:create => true)
      Rails.cache.delete "requests_new"
      flash[:note] = "Request #{params[id]} accepted and forwarded"
      redirect_to :controller => :request, :action => :show, :id => req.data["id"]
      return
    end

    change_request(changestate, params)
    Directory.free_cache( :project => req.action.target.project, :package => req.action.target.package )

    redirect_to :action => :show, :id => params[:id]
  end

  def diff
    # just for compatibility. OBS 1.X used this route for show
    redirect_to :action => :show, :id => params[:id]
  end

end
