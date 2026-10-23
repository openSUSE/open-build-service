module RoutesHelper
  class AnonymousMatcher
    def self.matches?(_request)
      ::Configuration.anonymous
    end
  end
end
