# typed: true
module WebuiControllerService
  class UserChecker
    attr_reader :user_login, :http_request
    def initialize(http_request:, config:)
      @http_request = http_request
      @config = config
      @user_login = extract_user_login_from_http_request
    end

    def proxy_enabled?
      @config['proxy_auth_mode'] == :on
    end

    def extract_user_login_from_http_request
      http_request.env['HTTP_X_USERNAME']
    end

    def find_or_create_user!
      if user.exists?
        User.find_by!(login: user_login)
      else
        User.create_user_with_fake_pw!(login: user_login,
                                       email: http_request.env['HTTP_X_EMAIL'],
                                       state: User.default_user_state,
                                       realname: realname)
      end
    end

    def login_exists?
      user.exists?
    end

    def user
      User.where(login: user_login)
    end

    def realname
      "#{http_request.env['HTTP_X_FIRSTNAME']} #{http_request.env['HTTP_X_LASTNAME']}".strip
    end
  end
end
