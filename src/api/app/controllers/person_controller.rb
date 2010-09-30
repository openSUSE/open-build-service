class PersonController < ApplicationController

  def userinfo
    if !@http_user
      logger.debug "No user logged in, permission to userinfo denied"
      @errorcode = 401
      @summary = "No user logged in, permission to userinfo denied"
      render :template => 'error', :status => 401
    else
      if request.get?
        if params[:login]
          login = URI.unescape( params[:login] )
          logger.debug "Generating for user from parameter #{login}"
          @render_user = User.find_by_login( login )
          if ! @render_user 
            logger.debug "User is not valid!"
            render_error :status => 404, :errorcode => 'unknown_user',
              :message => "Unknown user: #{login}"
          end
        else 
          logger.debug "Generating user info for logged in user #{@http_user.login}"
          @render_user = @http_user
        end
      # see the corresponding view users.rxml that generates a xml
      # response for the caller.

      elsif request.put?
        user = @http_user
      
        if user 
          if params[:login]
            login = URI.unescape( params[:login] )
            user = User.find_by_login( login )
            if user and user.login != @http_user.login 
              # TODO: check permission to update someone elses info
              if @http_user.is_admin?
                # ok, may update user info
              else
                logger.debug "User has no permission to change userinfo"
                render_error :status => 403, :errorcode => 'change_userinfo_no_permission',
                  :message => "no permission to change userinfo for user #{user.login}"
                return
              end
            end
            if !user and @http_user.is_admin?
              user = User.create( 
                     :login => login,
                     :password => "notset",
                     :password_confirmation => "notset",
                     :email => "TEMP" )
              user.state = "locked"
            end
          end
        
          xml = REXML::Document.new( request.raw_post )

          logger.debug( "XML: #{request.raw_post}" )

          user.email = xml.elements["/person/email"].text
          user.realname = xml.elements["/person/realname"].text

          e = xml.elements["/person/source_backend"]
          if ( e )
            user.source_host = e.elements['host'].text
            user.source_port = e.elements['port'].text
          end

          update_watchlist( user, xml )

          user.save!
          render_ok
        end
      end
    end
  
  end

  def watchlist
    valid_http_methods :get
    if !@http_user
      logger.debug "No user logged in, permission to userinfo denied"
      @errorcode = 401
      @summary = "No user logged in, permission to userinfo denied"
      render :template => 'error', :status => 401
    else
        if params[:login]
          login = URI.unescape( params[:login] )
          logger.debug "Generating for user from parameter #{login}"
          @render_user = User.find_by_login( login )
          if ! @render_user 
            logger.debug "User is not valid!"
            render_error :status => 404, :errorcode => 'unknown_user',
              :message => "Unknown user: #{login}"
          end
        else 
          logger.debug "Generating user info for logged in user #{@http_user.login}"
          @render_user = @http_user
        end
      # see the corresponding view watchlist.rxml that generates a xml
      # response for the caller.
    end
  end

  def register
    if defined?( LDAP_MODE ) && LDAP_MODE == :on
      render_error :message => "LDAP mode enabled, users can only be registered via LDAP", :errorcode => "err_register_save", :status => 400
      return
    end

    xml = REXML::Document.new( request.raw_post )
    
    logger.debug( "register XML: #{request.raw_post}" )

    login = xml.elements["/unregisteredperson/login"].text
    logger.debug("Found login #{login}")
    realname = xml.elements["/unregisteredperson/realname"].text
    email = xml.elements["/unregisteredperson/email"].text
    status = xml.elements["/unregisteredperson/state"].text
    password = xml.elements["/unregisteredperson/password"].text
    note = xml.elements["/unregisteredperson/note"].text

    if auth_method == :ichain
      if request.env['HTTP_X_USERNAME'].blank?
        render_error :message => "Missing iChain header", :errorcode => "err_register_save", :status => 400
        return
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
    newuser.state = status
    newuser.adminnote = note
    logger.debug("Saving...")
    newuser.save
    
    if !newuser.errors.empty?
      details = newuser.errors.map{ |key, msg| "#{key}: #{msg}" }.join(", ")
      
      render_error :message => "Could not save the registration",
                   :errorcode => "err_register_save",
                   :details => details, :status => 400
    else
      # create subscription for submit requests
      if Object.const_defined? :Hermes
        h = Hermes.new
        h.add_user(login, email)
        h.add_request_subscription(login)
      end

      IchainNotifier.deliver_approval(newuser)
      render_ok
    end
  end
  
  def update_watchlist( user, xml )
    new_watchlist = []
    old_watchlist = []

    xml.elements.each("/person/watchlist/project") do |e|
      new_watchlist << e.attributes['name']
    end

    user.watched_projects.each do |wp|
      old_watchlist << wp.name
    end
    add_to_watchlist = new_watchlist.collect {|i| old_watchlist.include?(i) ? nil : i}.compact
    remove_from_watchlist = old_watchlist.collect {|i| new_watchlist.include?(i) ? nil : i}.compact

    remove_from_watchlist.each do |name|
      WatchedProject.find_by_name( name, :conditions => [ 'bs_user_id = ?', user.id ] ).destroy
    end

    add_to_watchlist.each do |name|
      user.watched_projects << WatchedProject.new( :name => name )
    end
    true
  end
end
