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
          @render_user = BSUser.find_by_login( login )
          if ! @render_user 
            logger.debug "User is not valid!"
            render_error :status => 404, :message => "Unknown user: #{login}"
          end
        else 
          logger.debug "Generating user info for logged in user #{@http_user.login}"
          @render_user = @http_user
        end
        # see the corresponding view users.rxml that generates a xml
        # response for the caller.

      elsif request.put?
        user = @http_user
        if params[:login]
          login = URI.unescape( params[:login] )
          user = BSUser.find_by_login( login )
          if user and user.login != @http_user.login 
            # TODO: check permission to update someone elses info
            if @http_user.has_permission "Userinfo_Admin"
              # ok, may update user info
            else
              logger.debug "User has no permission to change userinfo"
              render_error :status => 401,
              :message => "no permission to change userinfo for user #{user.login}"
            end
          end
        end

        if user 
          xml = REXML::Document.new( request.raw_post )

          logger.debug( "XML: #{request.raw_post}" )

          realname = xml.elements["/person/realname"]
          user.realname = realname.text

          e = xml.elements["/person/source_backend"]
          if ( e )
            user.source_host = e.elements['host'].text
            user.source_port = e.elements['port'].text
          end

          e = xml.elements["/person/rpm_backend"]
          if ( e )
            user.rpm_host = e.elements['host'].text
            user.rpm_port = e.elements['port'].text
          end

          update_watchlist( user, xml )

          user.save
          render_ok
        else
          #create user if not existing
          logger.debug "trying to create new user"
          user = BSUser.create( 
            :login => login,
            :password => "asdfasdf",
            :password_confirmation => "asdfasdf",
            :email => "#{login}@localhost"
          )

          #user.login = params[:login]

          #logger.debug user
          #user.save
          render_ok
        end
      end
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
      WatchedProject.find_by_name( name, :conditions => "bs_user_id = #{user.id}" ).destroy
    end

    add_to_watchlist.each do |name|
      user.watched_projects << WatchedProject.new( :name => name )
    end
    true
  end
end
