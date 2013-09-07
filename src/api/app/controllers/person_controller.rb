require 'xmlhash'

class PersonController < ApplicationController

  validate_action :userinfo => {:method => :get, :response => :user}
  validate_action :userinfo => {:method => :put, :request => :user, :response => :status}
  validate_action :grouplist => {:method => :get, :response => :directory}
  validate_action :register => {:method => :put, :response => :status}
  validate_action :register => {:method => :post, :response => :status}

  skip_before_filter :extract_user, :only => [:index, :register]

  # Returns a list of all users (that optionally start with a prefix)
  def index
    unless request.post? and params[:cmd] == "register"
      
      if !extract_user
        logger.debug "No user logged in, permission to index denied"
        return
      end
    end

    if request.get?
      if params[:prefix]
        list = User.where("login LIKE ?", params[:prefix] + '%')
      else
        list = User.all
      end

      builder = Builder::XmlMarkup.new(:indent => 2)
      xml = builder.directory(:count => list.length) do |dir|
        list.each {|user| dir.entry(:name => user.login)}
      end
      render :text => xml, :content_type => "text/xml"
      return
    elsif request.post?
      if params[:cmd] == "register"
        internal_register
        return
      else
        render_error :status => 400, :errorcode => "unknown_command",
                     :message => "Allow commands are 'change_password'"
        return
      end
    end
  end

  def userinfo
    if !@http_user
      logger.debug "No user logged in, permission to userinfo denied"
      @errorcode = 401
      @summary = "No user logged in, permission to userinfo denied"
      render :template => 'error', :status => @errorcode and return
    end

    login = URI.unescape(params[:login]) if params[:login]
    user = User.find_by_login(login) if login

    if request.get?
      if not user
        logger.debug "Requested non-existing user"
        @errorcode = 404
        @summary = "Requested non-existing user"
        render_error status: @errorcode and return
      end
      if user.login != @http_user.login
        logger.debug "Generating for user from parameter #{user.login}"
        render :text => user.render_axml(false), :content_type => "text/xml"
      else
        logger.debug "Generating user info for logged in user #{@http_user.login}"
        render :text => @http_user.render_axml(true), :content_type => "text/xml"
      end
    elsif request.post?
      if params[:cmd] == "change_password"
        login ||= @http_user.login
        password = request.raw_post.to_s.chomp
        if login != @http_user.login and not @http_user.is_admin?
          render_error :status => 403, :errorcode => "change_password_no_permission",
                       :message => "No permission to change password for user #{login}"
          return
        end
        if password.blank?
          render_error :status => 404, :errorcode => "password_empty",
                       :message => "No new password given in first line of the body"
          return
        end
        change_password(login, password)
        render_ok
        return
      else
        render_error :status => 400, :errorcode => "unknown_command",
                     :message => "Allow commands are 'change_password'"
        return
      end
    elsif request.put?
      if user 
        unless user.login == User.current.login or User.current.is_admin?
          logger.debug "User has no permission to change userinfo"
          render_error :status => 403, :errorcode => 'change_userinfo_no_permission',
            :message => "no permission to change userinfo for user #{user.login}" and return
        end
      else
        if User.current.is_admin?
          user = User.create(:login => login, :password => "notset", :password_confirmation => "notset", :email => "TEMP")
          user.state = User.states["locked"]
        else
          logger.debug "Tried to create non-existing user without admin rights"
          @errorcode = 404
          @summary = "Requested non-existing user"
          render_error status: @errorcode and return
        end
      end

      xml = Xmlhash.parse(request.raw_post)
      logger.debug("XML: #{request.raw_post}")
      user.email = xml.value('email') || ''
      user.realname = xml.value('realname') || ''
      if User.current.is_admin?
        # only admin is allowed to change these, ignore for others
        user.state = User.states[xml.value('state')]
        update_globalroles(user, xml)
      end
      update_watchlist(user, xml)
      user.save!
      render_ok
    end
  end

  class NoPermissionToGroupList < APIException
    setup 401, "No user logged in, permission to grouplist denied"
  end

  def grouplist
    raise NoPermissionToGroupList.new unless User.current

    login = User.get_by_login params[:login]
    @list = User.lookup_strategy.groups(login)
  end

  def register
    # FIXME 3.0, to be removed
    internal_register
  end

  class ErrRegisterSave < APIException
  end

  def internal_register
    if CONFIG['ldap_mode'] == :on
      raise ErrRegisterSave.new "LDAP mode enabled, users can only be registered via LDAP"
    end
    if CONFIG['proxy_auth_mode'] == :on or CONFIG['ichain_mode'] == :on
      raise ErrRegisterSave.new "Proxy authentification mode, manual registration is disabled"
    end

    xml = REXML::Document.new( request.raw_post )
    
    logger.debug( "register XML: #{request.raw_post}" )

    login = xml.elements["/unregisteredperson/login"].text
    realname = xml.elements["/unregisteredperson/realname"].text
    email = xml.elements["/unregisteredperson/email"].text
    password = xml.elements["/unregisteredperson/password"].text
    note = xml.elements["/unregisteredperson/note"].text if xml.elements["/unregisteredperson/note"]
    status = "confirmed"

    unless User.current and User.current.is_admin?
      note = ""
    end

    if ::Configuration.first.registration == "deny"
      unless User.current and User.current.is_admin?
        raise ErrRegisterSave.new "User registration is disabled"
      end
    elsif ::Configuration.first.registration == "confirmation"
      status = "unconfirmed"
    elsif ::Configuration.first.registration != "allow"
      render_error :message => "Admin configured an unknown config option for registration",
                   :errorcode => "server_setup_error", :status => 500
      return
    end
    status = xml.elements["/unregisteredperson/state"].text if User.current and User.current.is_admin?

    if auth_method == :proxy
      if request.env['HTTP_X_USERNAME'].blank?
        raise ErrRegisterSave.new "Missing iChain header"
      end
      login = request.env['HTTP_X_USERNAME']
      email = request.env['HTTP_X_EMAIL'] unless request.env['HTTP_X_EMAIL'].blank?
      realname = request.env['HTTP_X_FIRSTNAME'] + " " + request.env['HTTP_X_LASTNAME'] unless request.env['HTTP_X_LASTNAME'].blank?
    end

    newuser = User.create( 
              :login => login,
              :password => password,
              :password_confirmation => password,
              :email => email )

    newuser.realname = realname
    newuser.state = User.states[status]
    newuser.adminnote = note
    logger.debug("Saving...")
    newuser.save
    
    if !newuser.errors.empty?
      details = newuser.errors.map{ |key, msg| "#{key}: #{msg}" }.join(", ")
      raise ErrRegisterSave.new "Could not save the registration, details: #{details}"
    end

    # create subscription for submit requests
    if Object.const_defined? :Hermes
      h = Hermes.new
      h.add_user(login, email)
      h.add_request_subscription(login)
    end

    # This may fail when no notification is configured. Not important, so no exception handling for now
    # IchainNotifier.deliver_approval(newuser)
    render_ok
  rescue Exception => e
    # Strip passwords from request environment and re-raise exception
    request.env["RAW_POST_DATA"] = request.env["RAW_POST_DATA"].sub(/<password>(.*)<\/password>/, "<password>STRIPPED<password>")
    raise e
  end
  
  def update_watchlist( user, xml )
    new_watchlist = []
    old_watchlist = []

    xml.get('watchlist').elements("project") do |e|
      new_watchlist << e['name']
    end

    user.watched_projects.each do |wp|
      old_watchlist << wp.project.name
    end
    add_to_watchlist = new_watchlist.collect {|i| old_watchlist.include?(i) ? nil : i}.compact
    remove_from_watchlist = old_watchlist.collect {|i| new_watchlist.include?(i) ? nil : i}.compact

    remove_from_watchlist.each do |name|
      user.watched_projects.where(project_id: Project.find_by_name(name).id).delete_all
    end

    add_to_watchlist.each do |name|
      user.watched_projects.new(project_id: Project.find_by_name(name).id)
    end

    return true
  end
  private :update_watchlist

  def update_globalroles( user, xml )
    new_globalroles = []
    old_globalroles = []

    xml.elements("globalrole") do |e|
      new_globalroles << e.to_s
    end

    user.roles.where(global: true).each do |ugr|
      old_globalroles << ugr.title
    end
    add_to_globalroles = new_globalroles.collect {|i| old_globalroles.include?(i) ? nil : i}.compact
    remove_from_globalroles = old_globalroles.collect {|i| new_globalroles.include?(i) ? nil : i}.compact

    remove_from_globalroles.each do |title|
      user.roles_users.where(role_id: Role.find_by_title!(title).id).delete_all
    end

    add_to_globalroles.each do |title|
      user.roles_users.new(role: Role.find_by_title!(title))
    end
    return true
  end
  private :update_globalroles

  def change_my_password
    #FIXME3.0: remove this function
    xml = REXML::Document.new( request.raw_post )

    logger.debug( "changepasswd XML: #{request.raw_post}" )

    login = xml.elements["/userchangepasswd/login"].text
    password = xml.elements["/userchangepasswd/password"].text
    login = URI.unescape(login)

    change_password(login, URI.unescape(password))
    render_ok
  end

  def change_password(login, password)
    if !User.current
      logger.debug "No user logged in, permission to changing password denied"
      @errorcode = 401
      @summary = "No user logged in, permission to changing password denied"
      render :template => 'error', :status => 401
    end

    if login.blank? or password.blank?
      render_error :status => 404, :errorcode => 'failed to change password',
            :message => "Failed to change password: missing parameter"
      return
    end
    unless User.current.is_admin? or login == User.current.login
      render_error :status => 403, :errorcode => 'failed to change password',
            :message => "No sufficiend permissions to change password for others"
      return
    end
    
    #change password to LDAP if LDAP is enabled    
    if CONFIG['ldap_mode'] == :on
      ldap_password = Base64.decode64(password)
      if CONFIG['ldap_ssl'] == :on
        require 'base64'
        begin
          logger.debug( "Using LDAP to change password for #{login}" )
          result = User.change_password_ldap(login, ldap_password)
        rescue Exception
          logger.debug "CONFIG['ldap_mode'] selected but 'ruby-ldap' module not installed."
        end
        if result
          render_error :status => 404, :errorcode => 'change_passwd_failure', :message => "Failed to change password to ldap: #{result}"
          return
        end
      else
        render_error :status => 404, :errorcode => 'change_passwd_no_security', :message => "LDAP mode enabled, the user password can only be changed with CONFIG['ldap_ssl'] enabling."
        return
      end
    end

    #update password in users db
    @user = User.get_by_login(login)
    @user.update_password( password )
    @user.save!
  end
  private :change_password

end
