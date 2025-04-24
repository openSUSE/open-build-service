module WebuiControllerService
  class UserChecker
    attr_reader :user_login, :user_email, :http_request

    def initialize(http_request:)
      @http_request = http_request
      @user_login = http_request.env['HTTP_X_USERNAME']
      @user_email = http_request.env['HTTP_X_EMAIL']
    end

    # Returns false if a user with a disabled account is trying to authenticate through the proxy
    def call
      return true unless ::Configuration.proxy_auth_mode_enabled?

      if user_login.blank? || user_email.blank?
        User.session = User.find_nobody!
        return true
      end

      User.session = find_or_create_user!

      if User.session.active?
        User.session.update_login_values(http_request.env)
        true
      else
        User.session.count_login_failure
        http_request.session[:login] = nil
        User.session = User.find_nobody!
        false
      end
    end

    private

    def find_or_create_user!
      if User.exists?(login: user_login)
        User.find_by!(login: user_login)
      else
        # This will end up in a before_validation(on: :create) that updates last_logged_in_at.
        User.create_user_with_fake_pw!(login: user_login,
                                       email: user_email,
                                       state: User.default_user_state,
                                       realname: realname)
      end
    end

    def realname
      "#{http_request.env['HTTP_X_FIRSTNAME']} #{http_request.env['HTTP_X_LASTNAME']}".strip
    end
  end
end
