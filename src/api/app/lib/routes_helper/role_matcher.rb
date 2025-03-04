module RoutesHelper
  class RoleMatcher
    def self.matches?(request)
      return false if request.bot?

      return false unless WebuiControllerService::UserChecker.new(http_request: request).call

      current_user_login = request.session[:login]
      current_user = current_user_login.present? ? User.find_by_login(current_user_login) : User.possibly_nobody

      current_user.admin? || current_user.staff?
    end
  end
end
