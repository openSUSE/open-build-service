module RoutesHelper
  class RoleMatcher
    def self.matches?(request)
      login = if ::Configuration.proxy_auth_mode_enabled?
                request.env['HTTP_X_USERNAME']
              else
                request.session[:login]
              end
      return false unless login

      user = User.find_by(login: login, state: :confirmed)
      return false unless user

      user.admin? || user.staff?
    end
  end
end
