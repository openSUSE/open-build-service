module RoutesHelper
  class RoleMatcher
    def self.matches?(request)
      Authenticator.new(request).extract_user

      return false unless User.session
      return false if User.session.state != 'confirmed'

      User.session.admin? || User.session.staff?
    end
  end
end
