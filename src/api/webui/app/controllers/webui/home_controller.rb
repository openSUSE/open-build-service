require 'net/http'

class Webui::HomeController < Webui::WebuiController

  before_filter :require_login, :except => [:icon, :index, :requests]
  before_filter :check_user, :except => [:icon]
  before_filter :overwrite_user, :only => [:index, :requests, :list_my]
  before_filter :lockout_spiders

  def index
    @iprojects = @displayed_user.involved_projects.pluck(:name, :title)
    @ipackages = @displayed_user.involved_packages.joins(:project).pluck(:name, 'projects.name as pname')

    @owned = []

    begin
      Owner.search({}, @displayed_user).each do |owner|
        @owned << [owner.project, owner.package]
      end
    rescue APIException => e # no attribute set
      Rails.logger.debug "0wned #{e.inspect}"
    end

    if User.current == @displayed_user
      requests
    end
  end

  def icon
    required_parameters :user
    user = params[:user]
    size = params[:size] || '20'
    key = "home_face_#{user}_#{size}"
    Rails.cache.delete(key) if discard_cache?
    content = Rails.cache.fetch(key, :expires_in => 5.hours) do

      if ::Configuration.use_gravatar?
        email = User.email_for_login(user)
        hash = Digest::MD5.hexdigest(email.downcase)
        begin
          content = ActiveXML.api.load_external_url("http://www.gravatar.com/avatar/#{hash}?s=#{size}&d=wavatar")
          content.force_encoding('ASCII-8BIT')
        rescue ActiveXML::Transport::Error
        end
      end

      content || 'none'
    end

    if content == 'none'
      redirect_to ActionController::Base.helpers.asset_path('default_face.png')
      return
    end

    expires_in 5.hours, public: true
    if stale?(etag: Digest::MD5.hexdigest(content))
      render text: content, layout: false, content_type: 'image/png'
    end
  end

  def running_patchinfos
    array = Array.new

    rel = PackageIssue.joins(:issue).where(issues: { state: 'OPEN', owner_id: @displayed_user.id})
    rel = rel.joins('LEFT JOIN package_kinds ON package_kinds.db_package_id = package_issues.db_package_id')
    ids = rel.where('package_kinds.kind="patchinfo"').pluck("distinct package_issues.db_package_id")

    Package.where(id: ids).each do |p|
      hash = {:package => {:project => p.project.name, :name => p.name}}
      issues = Array.new

      p.issues.each do |is|
        i = {}
        i[:name]= is.name
        i[:tracker]= is.issue_tracker.name
        i[:label]= is.label
        i[:url]= is.url
        i[:summary] = is.summary
        i[:state] = is.state
        i[:login] = is.owner.login if is.owner
        i[:updated_at] = is.updated_at
        issues << i
      end

      hash[:issues] = issues
      array << hash
    end

    return array
  end

  def requests
    login = @displayed_user.login

    # Reviews
    @open_reviews = BsRequestCollection.new(user: login, roles: ['reviewer'], reviewstates: ['new'], states: ['review']).relation
    @reviews_in = []
    @reviews_out = []
    @open_reviews.each do |review|
      if review["creator"] == @displayed_user.login
        @reviews_out << review
      else
        @reviews_in << review
      end
    end

    # Other requests
    @declined_requests = BsRequestCollection.new(user: login, states: ['declined'], roles: ['creator']).relation

    @open_requests = BsRequestCollection.new(user: login, states: ['new'], roles: ['maintainer']).relation
    @requests_in = []
    @requests_out = []
    @open_requests.each do |request|
      if request["creator"] == @displayed_user.login
        @requests_out << request
      else
        @requests_in << request
      end
    end

    @open_patchinfos = running_patchinfos

    session[:requests] = (@declined_requests.pluck(:id) +
        @open_reviews.pluck(:id) +
        @open_requests.pluck(:id))

    @requests = @declined_requests + @open_reviews + @open_requests
    @default_request_type = params[:type] if params[:type]
    @default_request_state = params[:state] if params[:state]

    respond_to do |format|
      format.html
      format.json do
        rawdata = Hash.new
        rawdata["review"] = @open_reviews
        rawdata["new"] = @open_requests
        rawdata["declined"] = @declined_requests
        rawdata["patchinfos"] = @open_patchinfos
        render :text => JSON.pretty_generate(rawdata)
      end
    end
  end

  def home_project
    redirect_to :controller => :project, :action => :show, :project => "home:#{User.current.login}"
  end

  def overwrite_user
    @displayed_user = User.current
    if params['user'].present?
      user = User.find_by_login(params['user'])
      if user
        @displayed_user = user
      else
        flash.now[:error] = "User not found #{params['user']}"
      end
    end
    if @displayed_user.is_nobody?
      flash[:error] = "Please log in"
      redirect_to :controller => :user, :action => :login
    end
    logger.debug "Displayed user is #{@displayed_user}"
  end

  private :overwrite_user
end
