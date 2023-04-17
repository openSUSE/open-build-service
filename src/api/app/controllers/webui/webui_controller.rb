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
  protect_from_forgery

  before_action :set_influxdb_data
  before_action :setup_view_path
  before_action :check_user
  before_action :check_anonymous
  before_action :require_configuration
  before_action :current_announcement
  after_action :clean_cache

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
    @project = ::Project.find_by(name: params[:project_name] || params[:project])
    raise ActiveRecord::RecordNotFound unless @project
  end

  def require_login
    return kerberos_auth if CONFIG['kerberos_mode']

    raise Pundit::NotAuthorizedError, reason: ApplicationPolicy::ANONYMOUS_USER unless User.session
  end

  def required_parameters(*parameters)
    parameters.each do |parameter|
      raise MissingParameterError, "Required Parameter #{parameter} missing" unless params.include?(parameter.to_s)
    end
  end

  def lockout_spiders
    return unless request.bot? && Rails.env.production?

    @spider_bot = true
    logger.debug "Spider blocked on #{request.fullpath}"
    head :ok
    true
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
        redirect_back(fallback_location: root_path)
        return
      end
      if User.session
        logger.info "User '#{User.session!}' has logged in via kerberos"
        session[:login] = User.session!.login
        redirect_back(fallback_location: root_path)
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
    @spider_bot = request.bot? && Rails.env.production?
    User.session = nil # reset old users hanging around

    unless WebuiControllerService::UserChecker.new(http_request: request, config: CONFIG).call
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
        redirect_back(fallback_location: root_path, error: "User not found #{param_login}") unless @displayed_user
      end
    else
      @displayed_user = User.possibly_nobody
    end
    @is_displayed_user = (User.session == @displayed_user)
  end

  def require_package
    required_parameters :package
    params[:rev], params[:package] = params[:pkgrev].split('-', 2) if params[:pkgrev]
    @project ||= params[:project]

    return if params[:package].blank?

    begin
      @package = Package.get_by_project_and_name(@project.to_param, params[:package],
                                                 follow_project_links: true, follow_multibuild: true)
    rescue APIError => e
      if [Package::Errors::ReadSourceAccessError, Authenticator::AnonymousUser].include?(e.class)
        flash[:error] = "You don't have access to the sources of this package: \"#{elide(params[:package])}\""
        redirect_back(fallback_location: project_show_path(@project))
        return
      end

      raise(ActiveRecord::RecordNotFound, 'Not Found') unless request.xhr?

      head :not_found
    end
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
    @configuration = ::Configuration.first
  end

  # Before filter to check if current user is administrator
  def require_admin
    return if User.admin_session?

    flash[:error] = 'Requires admin privileges'
    redirect_back(fallback_location: { controller: 'main', action: 'index' })
  end

  # before filter to only show the frontpage to anonymous users
  def check_anonymous
    if User.session
      false
    else
      unless ::Configuration.anonymous
        flash[:error] = 'No anonymous access. Please log in!'
        redirect_back(fallback_location: root_path)
      end
    end
  end

  # After filter to clean up caches
  def clean_cache; end

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

  def current_announcement
    @current_announcement = StatusMessage.latest_for_current_user
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

  def set_influxdb_data
    InfluxDB::Rails.current.tags = {
      beta: User.possibly_nobody.in_beta?,
      anonymous: !User.session,
      interface: :webui
    }
  end
end
