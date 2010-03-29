class RequestController < ApplicationController

  before_filter :check_user, :only => [ :list_req ]

  def index
    redirect_to :action => :list_req
  end

  def list_req
    @iprojects = @user.involved_projects.each.map {|x| x.name}.sort

    unless @iprojects.empty?
      predicate = @iprojects.map {|item| "action/target/@project='#{item}'"}.join(" or ")
      predicate2 = @iprojects.map {|item| "submit/target/@project='#{item}'"}.join(" or ") # old, to be removed later
      predicate = "state/@name='new' and (#{predicate} or #{predicate2})"
      collection = Collection.find :what => :request, :predicate => predicate
      @therequests_for_me = Array.new
      collection.each do |req| @therequests_for_me << req end
      collection = Collection.find :what => :request, :predicate => "state/@name='new' and state/@who='#{session[:login]}'"
      @therequests_by_me = Array.new
      collection.each do |req| @therequests_by_me << req end
    end
  end

  def diff
    if params[:id]
      @therequest = Request.find( :id => params[:id] )
    end
    unless @therequest
      flash[:error] = "Can't find request #{params[:id]}"
      redirect_to :action => :index
      return
    end

    @id = @therequest.data.attributes["id"]
    @state = @therequest.state.data.attributes["name"]
    @type = @therequest.action.data.attributes["type"]
    if @type=="submit"
      @src_project = @therequest.action.source.project
      @src_pkg = @therequest.action.source.package
    end
    @target_project = Project.find @therequest.action.target.project
    @target_pkg_name = @therequest.action.target.package
    @target_pkg = Package.find @target_pkg_name, :project => @therequest.action.target.project
    @is_author = @therequest.has_element? "//state[@name='new' and @who='#{session[:login]}']"
    @is_maintainer = @target_project.is_maintainer?( session[:login] ) ||
      (@target_pkg && @target_pkg.is_maintainer?( session[:login] ))

    if @type == "submit" and @target_pkg
      transport ||= ActiveXML::Config::transport_for(:project)
      path = "/source/%s/%s?opackage=%s&oproject=%s&cmd=diff&expand=1" %
      [CGI.escape(@src_project), CGI.escape(@src_pkg), CGI.escape(@target_pkg.name), CGI.escape(@target_project.name)]
      if @therequest.action.source.data['rev']
        path += "&rev=#{@therequest.action.source.rev}"
      end
      begin
        @diff_text =  transport.direct_http URI("https://#{path}"), :method => "POST", :data => ""
      rescue Object => e
        @diff_error = e.message
      end
    else
      @diff_error = nil
      @diff_text = nil
    end

    @revoke_own = (["revoke"].include? params[:changestate]) ? true : false
  
  end
 
  def change_request(changestate, params)
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

    if changestate == 'forward' # special case
      req = Request.find( params[:id] )
      description = req.description.text
      logger.debug 'request ' +  req.dump_xml

      if req.has_element? 'state'
        who = req.state.data["who"].to_s
        description += " (forwarded request %d from %s)" % [params[:id], who]
      end

      if not change_request('accepted', params)
        redirect_to :action => :diff, :id => params[:id]
        return
      end

      rev = Package.current_rev(req.action.target.project, req.action.target.package)
      req = Request.new(:type => "submit", :targetproject => params[:forward_project], :targetpackage => params[:forward_package],
        :project => req.action.target.project, :package => req.action.target.package, :rev => rev, :description => description)
      req.save(:create => true)
      Rails.cache.delete "requests_new"
      flash[:note] = "Request #{params[id]} accepted and forwarded"
      redirect_to :controller => :request, :action => :diff, :id => req.data["id"]
      return
    end

    change_request(changestate, params)

    redirect_to :action => :diff, :id => params[:id]
  end

end
