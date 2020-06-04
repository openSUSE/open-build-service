module AuthenticationProtocolHelper
  def kerberos_mode?
    CONFIG['kerberos_mode']
  end

  def proxy_mode?
    CONFIG['proxy_auth_mode'] == :on
  end

  def can_sign_up?
    return CONFIG['proxy_auth_register_page'].present? if proxy_mode?

    can_register?
  end

  def can_register?
    return false if kerberos_mode?
    return true if User.admin_session?

    begin
      UnregisteredUser.can_register?
    rescue APIError
      return false
    end
    true
  end

  def log_in_params
    if proxy_mode?
      { url: CONFIG['proxy_auth_login_page'], options: { method: :post, enctype: 'application/x-www-form-urlencoded' } }
    else
      { url: session_path, options: { method: :post } }
    end
  end

  def sign_up_params
    return { url: CONFIG['proxy_auth_register_page'] } if proxy_mode?

    { url: signup_path }
  end

  # last visited url in our app, unless it's the login/sign up path
  def return_to_location
    return root_path unless request.env['HTTP_REFERER'].to_s.start_with?(base_url)
    return root_path if request.env['HTTP_REFERER'].to_s.end_with?(new_session_path, new_user_path)

    request.env['HTTP_REFERER'].delete_prefix(base_url)
  end

  private

  def base_url
    "#{request.protocol}#{request.host}"
  end
end
