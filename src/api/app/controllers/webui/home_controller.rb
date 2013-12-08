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
    user = User.find_by_login! params[:user]
    size = params[:size].to_i || '20'
    content = user.gravatar_image(size)

    if content == :none
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
    rel = rel.joins('LEFT JOIN package_kinds ON package_kinds.package_id = package_issues.package_id')
    ids = rel.where('package_kinds.kind="patchinfo"').pluck('distinct package_issues.package_id')

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
    open_reviews = BsRequestCollection.new(user: login, roles: %w(reviewer creator), reviewstates: %w(new), states: %w(review)).relation
    @reviews_in = []
    open_reviews.each do |review|
      if review['creator'] != @displayed_user.login
        @reviews_in << review
      end
    end

    # Other requests
    @declined_requests = BsRequestCollection.new(user: login, states: %w(declined), roles: %w(creator)).relation

    @requests_in = BsRequestCollection.new(user: login, states: %w(new), roles: %w(maintainer)).relation
    @requests_out = BsRequestCollection.new(user: login, states: %w(new review), roles: %w(creator)).relation

    @open_patchinfos = running_patchinfos

    session[:requests] = @declined_requests.pluck(:id) + @reviews_in.map { |r| r.id } + @requests_in.pluck(:id)

    @requests = @declined_requests + @reviews_in + @requests_in
    @default_request_type = params[:type] if params[:type]
    @default_request_state = params[:state] if params[:state]

    respond_to do |format|
      format.html
      format.json { render_requests_json }
    end
  end

  def render_requests_json
    rawdata = Hash.new
    rawdata['review'] = @reviews_in.to_a
    rawdata['new'] = @requests_in.to_a
    rawdata['declined'] = @declined_requests.to_a
    rawdata['patchinfos'] = @open_patchinfos.to_a
    render json: Yajl::Encoder.encode(rawdata)
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
      flash[:error] = 'Please log in'
      redirect_to :controller => :user, :action => :login
    end
    logger.debug "Displayed user is #{@displayed_user}"
  end

  private :overwrite_user
end
