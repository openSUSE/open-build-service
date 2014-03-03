require_dependency 'api_exception'


class UnregisteredUser < User

  class ErrRegisterSave < APIException
  end

  def self.can_register?
    # No registering if LDAP is on
    if CONFIG['ldap_mode'] == :on
      logger.debug 'Someone tried to register with "ldap_mode" turned on'
      raise ErrRegisterSave.new 'Sorry, new users can only sign up via LDAP'
    end
    # No registering if we use an authentification proxy
    if CONFIG['proxy_auth_mode'] == :on or CONFIG['ichain_mode'] == :on
      logger.debug 'Someone tried to register with "proxy_auth_mode" turned on'
      if CONFIG['proxy_auth_register_page'].blank?
        raise ErrRegisterSave.new "Sorry, please sign up using the authentification proxy"
      else
        raise ErrRegisterSave.new "Sorry, please sign up using #{::Configuration.first.proxy_auth_register_page}"
      end
    end
    # Turn off registration if its disabled
    if ::Configuration.first.registration == 'never'
      unless User.current and User.current.is_admin?
        logger.debug 'Someone tried to register but its disabled'
        raise ErrRegisterSave.new 'Sorry, sign up is disabled'
      end
    end
    # Turn on registration if it's enabled
    if ::Configuration.first.registration == 'allow' or ::Configuration.first.registration == 'confirmation'
      return
    end
    # This shouldn't happen, but disable registration by default.
    logger.debug "Huh? This shouldn't happen. UnregisteredUser.can_register ran out of options"
    raise ErrRegisterSave.new 'Sorry, sign up is disabled'
  end

  def self.get_state
    state = User.states.key(User.default_state) 
    state = 'unconfirmed' if ::Configuration.first.registration == 'confirmation'
    state = 'confirmed' if ::Configuration.first.registration == 'allow'
    logger.debug "User state is: #{state}"
    return state
  end

  def self.register(opts)
    can_register?
    
    opts[:note] = nil unless User.current and User.current.is_admin?
    state = get_state
    
    newuser = User.create(
        :login => opts[:login],
        :password => opts[:password],
        :password_confirmation => opts[:password],
        :email => opts[:email] )

    newuser.realname = opts[:realname] || ""
    newuser.state = User.states[state]
    newuser.adminnote = opts[:note]
    logger.debug('Saving...')
    newuser.save

    if !newuser.errors.empty?
      details = newuser.errors.map{ |key, msg| "#{key}: #{msg}" }.join(', ')
      raise ErrRegisterSave.new "Could not save the registration, details: #{details}"
    end

    if newuser.state == User.states["unconfirmed"]
      raise ErrRegisterSave.new "Thank you for signing up! An admin has to confirm your account now. Please be patient."
    end

  end

end
