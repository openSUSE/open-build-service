module RoutesHelper
  class SessionAuthMatcher
    def self.matches?(_request)
      !::Configuration.proxy_auth_mode_enabled?
    end
  end
end
