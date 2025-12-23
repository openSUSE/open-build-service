# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class Webui::WebuiController < ActionController::Base
  layout 'webui/webui'

  Rails.cache.set_domain if Rails.cache.respond_to?(:set_domain)

  include Authenticator
  include Pundit::Authorization
  include FlipperFeature
  include Webui::RescueHandler
  include RescueAuthorizationHandler
  include SetCurrentRequestDetails
  include Webui::ElisionsHelper
  include ActiveStorage::SetCurrent

  protect_from_forgery

  before_action :authenticate_user!
  before_action :setup_view_path
  before_action :check_spider
  before_action :set_influxdb_data
  before_action :require_configuration
  before_action :current_announcement, unless: -> { request.xhr? }
  before_action :fetch_watchlist_items
  before_action :set_paper_trail_whodunnit

  # :notice and :alert are default, we add :success and :error
  add_flash_types :success, :error

  def home
    if params[:login].present?
      redirect_to user_path(params[:login])
    else
      redirect_to user_path(User.possibly_nobody)
    end
  end

  protected

  # We execute both strategies here. The default rails strategy (resetting the session)
  # and throwing an exception if the session is handled elswhere (e.g. proxy_auth_mode: :on)
  def handle_unverified_request
    super
    raise ActionController::InvalidAuthenticityToken
  end

  def set_project
    # We've started to use project_name for new routes...
    project_name = (params[:project_name] || params[:project]).to_s
    @project = ::Project.find_by(name: project_name)
    raise Project::Errors::UnknownObjectError, "Project not found: #{project_name}" unless @project
  end

  def require_login
    return if User.session

    if ::Configuration.proxy_auth_mode_enabled?
      case CONFIG['proxy_auth_mode']
      when :mellon
        redirect_to("#{CONFIG['proxy_auth_login_page']}?ReturnTo=#{CGI.escape(request.path)}", allow_other_host: true)
      else
        redirect_to("#{CONFIG['proxy_auth_login_page']}?url=#{CGI.escape(request.path)}", allow_other_host: true)
      end
    else
      redirect_back_or_to(new_session_path, error: 'Authentication Required', allow_other_host: false)
    end
  end

  def lockout_spiders
    return unless request.bot? && Rails.env.production?

    @spider_bot = true
    logger.debug "Spider blocked on #{request.fullpath}"
    head :ok
  end

  def check_displayed_user
    param_login = params[:login] || params[:user_login]
    if param_login.present?
      begin
        @displayed_user = User.not_deleted.find_by!(login: param_login)
      rescue ActiveRecord::RecordNotFound
        # admins can see deleted users
        @displayed_user = User.find_by_login(param_login) if User.admin_session?
        redirect_back_or_to(root_path, error: "User not found #{param_login}") unless @displayed_user
      end
    else
      @displayed_user = User.possibly_nobody
    end
    @is_displayed_user = (User.session == @displayed_user)
  end

  def set_package
    @package_name = params[:package] || params[:package_name]

    return if @package_name.blank?

    begin
      @package = Package.get_by_project_and_name(@project.name, @package_name, follow_multibuild: true)
    # why it's not found is of no concern
    rescue APIError
      raise Package::UnknownObjectError, "Package not found: #{@project.name}/#{@package_name}"
    end
  end

  def set_repository
    repository_name = params[:repository] || params[:repository_name]
    @repository = @project.repositories.find_by(name: repository_name)
    return if @repository

    flash[:error] = "Could not find repository '#{repository_name}'"

    redirect_back_or_to repositories_path(project: @project, package: @package)
  end

  def set_architecture
    architecture_name = params[:architecture] || params[:architecture_name] || params[:arch]
    @architecture = @repository.architectures.find_by(name: architecture_name)
    return if @architecture

    flash[:error] = "Could not find architecture '#{architecture_name}'"
    redirect_back_or_to project_repositories_path(@project)
  end

  # Find the right object to authorize for all cases of links
  # https://github.com/openSUSE/open-build-service/wiki/Links
  def set_object_to_authorize
    @object_to_authorize = @project
    return unless @package # Remote Project Links or Project SCM Bridge Links
    return if @project != @package.project # Project Links or Update Instance Project Links

    @object_to_authorize = @package
  end

  private

  def require_configuration
    @configuration = ::Configuration.fetch
  end

  # Before filter to check if current user is administrator
  def require_admin
    return if User.admin_session?

    flash[:error] = 'Requires admin privileges'
    redirect_to({ controller: 'main', action: 'index' })
  end

  def setup_view_path
    return unless CONFIG['theme']

    theme_path = Rails.root.join('app', 'views', 'webui', 'theme', CONFIG['theme'])
    prepend_view_path(theme_path)
  end

  def check_ajax
    raise ActionController::RoutingError, 'Expected AJAX call' unless request.xhr?
  end

  def pundit_user
    User.possibly_nobody
  end

  # TODO: This wouldn't be required if we used fairly common standard current_user function
  def user_for_paper_trail
    User.session&.id
  end

  def current_announcement
    @current_announcement = StatusMessage.latest_for_current_user
  end

  def fetch_watchlist_items
    if request.xhr? && action_name != 'toggle_watched_item'
      @watched_requests = []
      @watched_packages = []
      @watched_projects = []
    else
      @watched_requests = User.possibly_nobody.watched_requests
      @watched_packages = User.possibly_nobody.watched_packages
      @watched_projects = User.possibly_nobody.watched_projects
    end
  end

  def add_arrays(arr1, arr2)
    # we assert that both have the same size
    ret = []
    if arr1
      arr1.length.times do |i|
        time1, value1 = arr1[i]
        time2, value2 = arr2[i]
        value2 ||= 0
        value1 ||= 0
        time1 ||= 0
        time2 ||= 0
        ret << [(time1 + time2) / 2, value1 + value2]
      end
    end
    ret << 0 if ret.empty?
    ret
  end

  def check_spider
    @spider_bot = if Rails.env.production?
                    request.bot?
                  else
                    false
                  end
  end

  def set_influxdb_data
    InfluxDB::Rails.current.tags = {
      beta: User.possibly_nobody.in_beta?,
      anonymous: !User.session,
      spider: @spider_bot,
      interconnect: false,
      interface: :webui
    }
  end
end
