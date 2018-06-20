# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require_dependency 'authenticator'

class Webui::WebuiController < ActionController::Base
  layout :choose_layout

  helper_method :valid_xml_id

  Rails.cache.set_domain if Rails.cache.respond_to?('set_domain')

  include Pundit
  protect_from_forgery

  before_action :setup_view_path
  before_action :set_breadcrumbs
  before_action :check_user
  before_action :check_anonymous
  before_action :require_configuration
  after_action :clean_cache

  # :notice and :alert are default, we add :success and :error
  add_flash_types :success, :error

  rescue_from Pundit::NotAuthorizedError do |exception|
    pundit_action = case exception.try(:query).to_s
                    when 'index?' then 'list'
                    when 'show?' then 'view'
                    when 'create?' then 'create'
                    when 'new?' then 'create'
                    when 'update?' then 'update'
                    when 'edit?' then 'edit'
                    when 'destroy?' then 'delete'
                    when 'branch?' then 'branch'
                    else exception.try(:query)
    end
    if pundit_action && exception.record
      message = "Sorry, you are not authorized to #{pundit_action} this #{exception.record.class}."
    else
      message = 'Sorry, you are not authorized to perform this action.'
    end
    if request.xhr?
      render json: { error: message }, status: 400
    else
      flash[:error] = message
      redirect_back(fallback_location: root_path)
    end
  end

  # FIXME: This belongs into the user controller my dear.
  # Also it would be better, but also more complicated, to just raise
  # HTTPPaymentRequired, UnauthorizedError or Forbidden
  # here so the exception handler catches it but what the heck...
  rescue_from ActiveXML::Transport::ForbiddenError do |exception|
    case exception.code
    when 'unregistered_ichain_user'
      render template: 'user/request_ichain'
    when 'unregistered_user'
      render file: Rails.root.join('public/403'), formats: [:html], status: 402, layout: false
    when 'unconfirmed_user'
      render file: Rails.root.join('public/402'), formats: [:html], status: 402, layout: false
    else
      if User.current.is_nobody?
        render file: Rails.root.join('public/401'), formats: [:html], status: :unauthorized, layout: false
      else
        render file: Rails.root.join('public/403'), formats: [:html], status: :forbidden, layout: false
      end
    end
  end

  # FIXME: This is more than stupid. Why do we tell the user that something isn't found
  # just because there is some data missing to compute the request? Someone needs to read
  # http://guides.rubyonrails.org/active_record_validations.html
  class MissingParameterError < RuntimeError; end
  rescue_from MissingParameterError do |exception|
    logger.debug "#{exception.class.name} #{exception.message} #{exception.backtrace.join('\n')}"
    render file: Rails.root.join('public/404'), status: 404, layout: false, formats: [:html]
  end

  def valid_xml_id(rawid)
    rawid = "_#{rawid}" if rawid !~ /^[A-Za-z_]/ # xs:ID elements have to start with character or '_'
    CGI.escapeHTML(rawid.gsub(/[+&: .\/\~\(\)@#]/, '_'))
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
    @project = Project.find_by(name: params[:project_name] || params[:project])
    raise ActiveRecord::RecordNotFound unless @project
  end

  def require_login
    if CONFIG['kerberos_mode']
      kerberos_auth
    else
      if User.current.nil? || User.current.is_nobody?
        render(text: 'Please login') && (return false) if request.xhr?

        flash[:error] = 'Please login to access the requested page.'
        mode = CONFIG['proxy_auth_mode'] || :off
        if mode == :off
          redirect_to session_new_path
        else
          redirect_to root_path
        end
        return false
      end
      true
    end
  end

  def required_parameters(*parameters)
    parameters.each do |parameter|
      unless params.include? parameter.to_s
        raise MissingParameterError, "Required Parameter #{parameter} missing"
      end
    end
  end

  def lockout_spiders
    @spider_bot = request.bot?
    if @spider_bot
      head :ok
      return true
    end
    false
  end

  def kerberos_auth
    return true unless CONFIG['kerberos_mode'] && (User.current.nil? || User.current.is_nobody?)

    authorization = authenticator.authorization_infos || []
    if authorization[0].to_s != 'Negotiate'
      # Demand kerberos negotiation
      response.headers['WWW-Authenticate'] = 'Negotiate'
      render :new, status: 401
      return
    else
      begin
        authenticator.extract_user
      rescue Authenticator::AuthenticationRequiredError => e
        logger.info "Authentication via kerberos failed '#{e.message}'"
        flash[:error] = "Authentication failed: '#{e.message}'"
        redirect_back(fallback_location: root_path)
        return
      end
      if User.current
        logger.info "User '#{User.current}' has logged in via kerberos"
        session[:login] = User.current.login
        redirect_back(fallback_location: root_path)
        return true
      end
    end
  end

  def check_user
    @spider_bot = request.bot?
    User.current = nil # reset old users hanging around
    if CONFIG['proxy_auth_mode'] == :on
      logger.debug 'Authenticating with proxy auth mode'
      user_login = request.env['HTTP_X_USERNAME']
      if user_login.blank?
        User.current = User.find_nobody!
        return
      end

      # The user does not exist in our database, create her.
      unless User.where(login: user_login).exists?
        logger.debug "Creating user #{user_login}"
        User.create_user_with_fake_pw!(login: user_login,
                                       email: request.env['HTTP_X_EMAIL'],
                                       state: User.default_user_state,
                                       realname: "#{request.env['HTTP_X_FIRSTNAME']} #{request.env['HTTP_X_LASTNAME']}".strip)
      end

      # The user exists, check if shes active and update the info
      User.current = User.find_by(login: user_login)
      unless User.current.is_active?
        session[:login] = nil
        User.current = User.find_nobody!
        redirect_to(CONFIG['proxy_auth_logout_page'], error: 'Your account is disabled. Please contact the administrator for details.')
        return
      end
      User.current.update_user_info_from_proxy_env(request.env)
    end

    User.current = User.find_by_login(session[:login]) if session[:login]
    User.current ||= User.find_nobody!
  end

  def check_display_user
    if params['user'].present?
      begin
        @displayed_user = User.find_by_login!(params['user'])
      rescue NotFoundError
        # admins can see deleted users
        @displayed_user = User.find_by_login(params['user']) if User.current && User.current.is_admin?
        redirect_back(fallback_location: root_path, error: "User not found #{params['user']}") unless @displayed_user
      end
    else
      @displayed_user = User.current
      @displayed_user ||= User.find_nobody!
    end
    @is_displayed_user = User.current == @displayed_user
  end

  def map_to_workers(arch)
    case arch
    when 'i586' then 'x86_64'
    when 'ppc' then 'ppc64'
    when 's390' then 's390x'
    else arch
    end
  end

  # Don't show performance of database queries to users
  def peek_enabled?
    User.current && (User.current.is_admin? || User.current.is_staff?)
  end

  def require_package
    required_parameters :package
    params[:rev], params[:package] = params[:pkgrev].split('-', 2) if params[:pkgrev]
    @project ||= params[:project]
    if params[:package].present?
      begin
        @package = Package.get_by_project_and_name(@project.to_param, params[:package],
                                                   use_source: false, follow_project_links: true, follow_multibuild: true)
      rescue APIException # why it's not found is of no concern :)
      end
    end

    return if @package

    if request.xhr?
      render nothing: true, status: :not_found
    else
      flash[:error] = "Package \"#{params[:package]}\" not found in project \"#{params[:project]}\""
      redirect_to project_show_path(project: @project, nextstatus: 404)
    end
  end

  def feature_active?(feature)
    return if Feature.active?(feature)
    render file: Rails.root.join('public/404'), status: :not_found, layout: false
  end

  private

  def authenticator
    @authenticator ||= Authenticator.new(request, session, response)
  end

  def require_configuration
    @configuration = ::Configuration.first
  end

  # Before filter to check if current user is administrator
  def require_admin
    return unless User.current.nil? || !User.current.is_admin?
    flash[:error] = 'Requires admin privileges'
    redirect_back(fallback_location: { controller: 'main', action: 'index' })
  end

  # before filter to only show the frontpage to anonymous users
  def check_anonymous
    if User.current && User.current.is_nobody?
      unless ::Configuration.anonymous
        flash[:error] = 'No anonymous access. Please log in!'
        redirect_back(fallback_location: root_path)
      end
    else
      false
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
    return if User.current.is_nobody?
    return User.current
  end

  # dialog_init is a function name called before dialog is shown
  def render_dialog(dialog_init = nil)
    check_ajax
    @dialog_html = ActionController::Base.helpers.escape_javascript(render_to_string(partial: action_name))
    @dialog_init = dialog_init
    render partial: 'dialog', content_type: 'application/javascript'
  end

  def switch_to_webui2?
    Feature.active?(:bootstrap)
  end

  def choose_layout
    @switch_to_webui2 ? 'webui2/webui' : 'webui/webui'
  end

  def switch_to_webui2
    if switch_to_webui2?
      @switch_to_webui2 = true
      prepend_view_path('app/views/webui2')
      prefixed_action_name = "webui2_#{action_name}"
      send(prefixed_action_name) if action_methods.include?(prefixed_action_name)
      return true
    end
    @switch_to_webui2 = false
  end

  def set_breadcrumbs
    name = @configuration ? @configuration['title'] : 'Open Build Service'
    @breadcrumbs = [
      { name: name, path: root_path }
    ]
  end
end
