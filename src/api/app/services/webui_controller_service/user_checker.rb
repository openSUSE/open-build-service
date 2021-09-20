module WebuiControllerService
  class UserChecker
    attr_reader :user_login, :http_request

    def initialize(http_request:, config:)
      @http_request = http_request
      @config = config
      @user_login = extract_user_login_from_http_request
    end

    # Returns false if a user with a disabled account is trying to authenticate through the proxy
    def call
      return true unless proxy_enabled?

      if user_login.blank?
        User.session = User.find_nobody!
        return true
      end

      User.session = find_or_create_user!

      if User.session!.is_active?
        User.session!.update_login_values(http_request.env)
        true
      else
        User.session!.count_login_failure
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
                                       email: http_request.env['HTTP_X_EMAIL'],
                                       state: User.default_user_state,
                                       realname: realname)
      end
    end

    def proxy_enabled?
      @config['proxy_auth_mode'] == :on
    end

    def realname
      "#{http_request.env['HTTP_X_FIRSTNAME']} #{http_request.env['HTTP_X_LASTNAME']}".strip
    end

    def extract_user_login_from_http_request
      http_request.env['HTTP_X_USERNAME']
    end
  end
end
