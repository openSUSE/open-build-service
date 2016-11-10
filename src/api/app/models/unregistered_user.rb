require_dependency 'api_exception'

class UnregisteredUser < User
  class ErrRegisterSave < APIException
  end

  # Raises an exception if registration is disabled for a user
  # Returns true if a user can register
  def self.can_register?
    # No registering if LDAP is on
    if CONFIG['ldap_mode'] == :on
      logger.debug 'Someone tried to register with "ldap_mode" turned on'
      raise ErrRegisterSave, 'Sorry, new users can only sign up via LDAP'
    end

    # No registering if we use an authentification proxy
    if CONFIG['proxy_auth_mode'] == :on || CONFIG['ichain_mode'] == :on
      logger.debug 'Someone tried to register with "proxy_auth_mode" turned on'
      if CONFIG['proxy_auth_register_page'].blank?
        err_msg = "Sorry, please sign up using the authentification proxy"
      else
        err_msg = "Sorry, please sign up using #{CONFIG['proxy_auth_register_page']}"
      end
      raise ErrRegisterSave, err_msg
    end

    # Turn off registration if its disabled
    if ::Configuration.registration == 'deny'
      return true if User.current.try(:is_admin?)
      logger.debug 'Someone tried to register but its disabled'
      raise ErrRegisterSave, 'Sorry, sign up is disabled'
    end

    # Turn on registration if it's enabled
    if ["allow", "confirmation"].include?(::Configuration.registration)
      return true
    end

    # This shouldn't happen, but disable registration by default.
    logger.debug "Huh? This shouldn't happen. UnregisteredUser.can_register ran out of options"
    raise ErrRegisterSave, 'Sorry, sign up is disabled'
  end

  def self.register(opts)
    can_register?

    opts[:note] = nil unless User.current && User.current.is_admin?
    state = ::Configuration.registration == 'allow' ? "confirmed" : "unconfirmed"

    newuser = User.create(
        login: opts[:login],
        password: opts[:password],
        email: opts[:email] )

    newuser.realname = opts[:realname] || ""
    newuser.state = state
    newuser.adminnote = opts[:note]
    logger.debug("Saving new user #{newuser.login}")
    newuser.save

    if !newuser.errors.empty?
      details = newuser.errors.map{ |key, msg| "#{key}: #{msg}" }.join(', ')
      raise ErrRegisterSave.new "Could not save the registration, details: #{details}"
    end

    if newuser.state == "unconfirmed"
      raise ErrRegisterSave.new "Thank you for signing up! An admin has to confirm your account now. Please be patient."
    end
  end
end
