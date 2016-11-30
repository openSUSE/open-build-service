# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class Webui::WebuiController < ActionController::Base
  helper_method :valid_xml_id

  Rails.cache.set_domain if Rails.cache.respond_to?('set_domain')

  include Pundit
  protect_from_forgery

  before_action :setup_view_path
  before_action :instantiate_controller_and_action_names
  before_action :check_user
  before_action :check_anonymous
  before_action :require_configuration
  after_action :clean_cache

  # We execute both strategies here. The default rails strategy (resetting the session)
  # and throwing an exception if the session is handled elswhere (e.g. proxy_auth_mode: :on)
  def handle_unverified_request
    super
    raise ActionController::InvalidAuthenticityToken
  end

  # :notice and :alert are default, we add :success and :error
  add_flash_types :success, :error

  rescue_from Pundit::NotAuthorizedError do |exception|
    pundit_action = case exception.query.to_s
       when "index?" then "list"
       when "show?" then "view"
       when "create?" then "create"
       when "new?" then "create"
       when "update?" then "update"
       when "edit?" then "edit"
       when "destroy?" then "delete"
       when "branch?" then "branch"
       else exception.query
    end
    if pundit_action && exception.record
      message = "Sorry, you are not authorized to #{pundit_action} this #{exception.record.class}."
    else
      message = "Sorry, you are not authorized to perform this action."
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
    when "unregistered_ichain_user"
      render template: "user/request_ichain"
    when "unregistered_user"
      render file: Rails.root.join('public/403'), formats: [:html], status: 402, layout: false
    when "unconfirmed_user"
      render file: Rails.root.join('public/402'), formats: [:html], status: 402, layout: false
    else
      if User.current.is_nobody?
        render file: Rails.root.join('public/401'), formats: [:html], status: :unauthorized, layout: false
      else
        render file: Rails.root.join('public/403'), formats: [:html], status: :forbidden, layout: false
      end
    end
  end

  rescue_from ActionController::RedirectBackError do
    redirect_to root_path
  end

  class ValidationError < Exception
    attr_reader :xml, :errors

    def message
      errors
    end

    def initialize( _xml, _errors )
      @xml = _xml
      @errors = _errors
    end
  end

  # FIXME: This is more than stupid. Why do we tell the user that something isn't found
  # just because there is some data missing to compute the request? Someone needs to read
  # http://guides.rubyonrails.org/active_record_validations.html
  class MissingParameterError < Exception; end
  rescue_from MissingParameterError do |exception|
    logger.debug "#{exception.class.name} #{exception.message} #{exception.backtrace.join('\n')}"
    render file: Rails.root.join('public/404'), status: 404, layout: false, formats: [:html]
  end

  def set_project
    @project = Project.find_by(name: params[:project])
    raise ActiveRecord::RecordNotFound unless @project
  end

  def set_project_by_id
    @project = Project.find(params[:id])
  end

  def valid_xml_id(rawid)
    rawid = "_#{rawid}" if rawid !~ /^[A-Za-z_]/ # xs:ID elements have to start with character or '_'
    CGI.escapeHTML(rawid.gsub(/[+&: .\/\~\(\)@#]/, '_'))
  end

  protected

  # Renders a json response for jquery dataTables
  def render_json_response_for_dataTable(options)
    options[:draw] ||= 1
    options[:total_records_count] ||= 0
    options[:total_displayed_records] ||= 0
    response = {
      draw:            options[:draw].to_i,
      recordsTotal:    options[:total_records_count].to_i,
      recordsFiltered: options[:total_filtered_records_count].to_i,
      data:            options[:records].map do |record|
        if block_given?
          yield record
        else
          record
        end
      end
    }
    render json: Yajl::Encoder.encode(response)
  end

  def require_login
    if User.current.nil? || User.current.is_nobody?
      render(text: 'Please login') && (return false) if request.xhr?

      flash[:error] = 'Please login to access the requested page.'
      mode = CONFIG['proxy_auth_mode'] || :off
      if mode == :off
        redirect_to controller: :user, action: :login
      else
        redirect_to controller: :main
      end
      return false
    end
    true
  end

  def required_parameters(*parameters)
    parameters.each do |parameter|
      unless params.include? parameter.to_s
        raise MissingParameterError.new "Required Parameter #{parameter} missing"
      end
    end
  end

  def discard_cache?
    cc = request.headers['HTTP_CACHE_CONTROL']
    return false if cc.blank?
    return true if cc == 'max-age=0'
    return false unless cc == 'no-cache'
    !request.xhr?
  end

  def find_hashed(classname, *args)
    ret = classname.find( *args )
    return Xmlhash::XMLHash.new({}) unless ret
    ret.to_hash
  end

  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
  end

  # Needed to hide/render some views to well known spider bots
  # FIXME: We should get rid of it
  def check_spiders
    @spider_bot = request.bot?
  end
  private :check_spiders

  def lockout_spiders
    check_spiders
    if @spider_bot
      head :ok
      return true
    end
    false
  end

  def check_user
    check_spiders
    User.current = nil # reset old users hanging around

    if CONFIG['proxy_auth_mode'] == :on
      logger.debug "Authenticating with proxy auth mode"
      user_login = request.env['HTTP_X_USERNAME']
      if user_login.blank?
        User.current = User.find_nobody!
        return
      end

      # The user does not exist in our database, create her.
      unless User.where(login: user_login).exists?
        logger.debug "Creating user #{user_login}"
        chars = ["A".."Z", "a".."z", "0".."9"].collect { |r| r.to_a }.join
        fakepw = (1..24).collect { chars[rand(chars.size)] }.pack("a"*24)
        User.create!(login: user_login,
                     email: request.env['HTTP_X_EMAIL'],
                     state: User.default_user_state,
                     realname: "#{request.env['HTTP_X_FIRSTNAME']} #{request.env['HTTP_X_LASTNAME']}".strip,
                     password: fakepw)
      end

      # The user exists, check if shes active and update the info
      User.current = User.find_by(login: user_login)
      unless User.current.is_active?
        session[:login] = nil
        User.current = User.find_nobody!
        redirect_to(CONFIG['proxy_auth_logout_page'], error: "Your account is disabled. Please contact the adminsitrator for details.")
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
  end

  def map_to_workers(arch)
    case arch
    when 'i586' then 'x86_64'
    when 'ppc' then 'ppc64'
    when 's390' then 's390x'
    else arch
    end
  end

  private

  def put_body_to_tempfile(xmlbody)
    file = Tempfile.new('xml').path
    file = File.open(file + '.xml', 'w')
    file.write(xmlbody)
    file.close
    file.path
  end
  private :put_body_to_tempfile

  def require_configuration
    @configuration = ::Configuration.first
  end

  # Before filter to check if current user is administrator
  def require_admin
    if User.current.nil? || !User.current.is_admin?
      flash[:error] = 'Requires admin privileges'
      redirect_back(fallback_location: { controller: 'main', action: 'index' })
      return
    end
  end

  # before filter to only show the frontpage to anonymous users
  def check_anonymous
    if User.current && User.current.is_nobody?
      unless ::Configuration.anonymous
        flash[:error] = "No anonymous access. Please log in!"
        redirect_back(fallback_location: root_path)
      end
    else
      false
    end
  end

  # After filter to clean up caches
  def clean_cache
  end

  def setup_view_path
    if CONFIG['theme']
      theme_path = Rails.root.join('app', 'views', 'webui', 'theme', CONFIG['theme'])
      prepend_view_path(theme_path)
    end
  end

  def check_ajax
    raise ActionController::RoutingError.new('Expected AJAX call') unless request.xhr?
  end

  def pundit_user
    if User.current.is_nobody?
      return nil
    else
      return User.current
    end
  end

  # dialog_init is a function name called before dialog is shown
  def render_dialog(dialog_init = nil)
    check_ajax
    @dialog_html = ActionController::Base.helpers.escape_javascript(render_to_string(partial: @current_action.to_s))
    @dialog_init = dialog_init
    render partial: 'dialog', content_type: 'application/javascript'
  end
end
