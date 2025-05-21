# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class Webui::WebuiController < ActionController::Base
  layout 'webui/webui'

  Rails.cache.set_domain if Rails.cache.respond_to?(:set_domain)

  include Pundit::Authorization
  include FlipperFeature
  include Webui::RescueHandler
  include RescueAuthorizationHandler
  include SetCurrentRequestDetails
  include Webui::ElisionsHelper
  include ActiveStorage::SetCurrent
  protect_from_forgery

  before_action :setup_view_path
  before_action :check_user
  before_action :check_spider
  before_action :set_influxdb_data
  before_action :check_anonymous
  before_action :require_configuration
  before_action :current_announcement, unless: -> { request.xhr? }
  before_action :fetch_watchlist_items
  before_action :set_paper_trail_whodunnit
  before_action :set_unread_notifications_count, unless: -> { request.xhr? }

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
    return kerberos_auth if CONFIG['kerberos_mode']

    raise Pundit::NotAuthorizedError, reason: ApplicationPolicy::ANONYMOUS_USER unless User.session
  end

  def lockout_spiders
    return unless request.bot? && Rails.env.production?

    @spider_bot = true
    logger.debug "Spider blocked on #{request.fullpath}"
    head :ok
  end

  def kerberos_auth
    return true unless CONFIG['kerberos_mode'] && !User.session

    authorization = authenticator.authorization_infos || []
    if authorization[0].to_s == 'Negotiate'
      begin
        authenticator.extract_user
      rescue Authenticator::AuthenticationRequiredError => e
        logger.info "Authentication via kerberos failed '#{e.message}'"
        flash[:error] = "Authentication failed: '#{e.message}'"
        redirect_back_or_to root_path
        return
      end
      if User.session
        logger.info "User '#{User.session}' has logged in via kerberos"
        session[:login] = User.session.login
        redirect_back_or_to root_path
        true
      end
    else
      # Demand kerberos negotiation
      response.headers['WWW-Authenticate'] = 'Negotiate'
      render :new, status: :unauthorized
      nil
    end
  end

  def check_user
    User.session = nil # reset old users hanging around

    unless WebuiControllerService::UserChecker.new(http_request: request).call
      redirect_to(CONFIG['proxy_auth_logout_page'], error: 'Your account is disabled. Please contact the administrator for details.')
      return
    end

    User.session = User.find_by_login(session[:login]) if session[:login]

    User.session ||= User.possibly_nobody
  end

  def check_displayed_user
    param_login = params[:login] || params[:user_login]
    if param_login.present?
      begin
        @displayed_user = User.find_by_login!(param_login)
      rescue NotFoundError
        # admins can see deleted users
        @displayed_user = User.find_by_login(param_login) if User.admin_session?
        redirect_back_or_to(root_path, error: "User not found #{param_login}") unless @displayed_user
      end
    else
      @displayed_user = User.possibly_nobody
    end
    @is_displayed_user = (User.session == @displayed_user)
  end

  def require_package
    params[:rev], params[:package] = params[:pkgrev].split('-', 2) if params[:pkgrev]
    @package_name = params[:package] || params[:package_name]

    return if @package_name.blank?

    begin
      @package = Package.get_by_project_and_name(@project.name, @package_name, follow_multibuild: true)
    # why it's not found is of no concern
    rescue APIError
      raise Package::UnknownObjectError, "Package not found: #{@project.name}/#{@package_name}"
    end
  end
  alias set_package require_package

  def set_repository
    repository_name = params[:repository] || params[:repository_name]
    @repository = @project.repositories.find_by(name: repository_name)
    return if @repository

    flash[:error] = "Could not find repository '#{repository_name}'"

    redirect_back_or_to repositories_path(project: @project, package: @package)
  end

  def set_architecture
    architecture_name = params[:architecture] || params[:arch]
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

  def send_login_information_rabbitmq(msg)
    message_mapping = { success: 'login,access_point=webui value=1',
                        disabled: 'login,access_point=webui,failure=disabled value=1',
                        logout: 'logout,access_point=webui value=1',
                        unauthenticated: 'login,access_point=webui,failure=unauthenticated value=1' }
    RabbitmqBus.send_to_bus('metrics', message_mapping[msg])
  end

  def authenticator
    @authenticator ||= Authenticator.new(request, session, response)
  end

  def require_configuration
    @configuration = ::Configuration.fetch
  end

  # Before filter to check if current user is administrator
  def require_admin
    return if User.admin_session?

    flash[:error] = 'Requires admin privileges'
    redirect_to({ controller: 'main', action: 'index' })
  end

  # before filter to only show the frontpage to anonymous users
  def check_anonymous
    return if User.session.present?
    return if ::Configuration.anonymous

    login_page = case CONFIG['proxy_auth_mode']
                 when :mellon
                   add_return_to_parameter_to_query(url: CONFIG['proxy_auth_login_page'], parameter_name: 'ReturnTo')
                 when :ichain
                   add_return_to_parameter_to_query(url: CONFIG['proxy_auth_login_page'], parameter_name: 'url')
                 else
                   root_path
                 end

    flash[:error] = 'No anonymous access. Please log in!' unless ::Configuration.proxy_auth_mode_enabled?
    redirect_to login_page
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

  def set_unread_notifications_count
    @unread_notifications_count = User.session ? User.session.unread_notifications_count : 0
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

  def add_return_to_parameter_to_query(url:, parameter_name:)
    uri = URI(url)
    return_to = {}
    return_to[parameter_name] = request.fullpath
    query_array = uri.query.to_s.split('&')
    query_array << return_to.to_query # for URL encoding
    uri.query = query_array.join('&')

    uri.to_s
  end
end
