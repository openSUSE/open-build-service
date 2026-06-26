# here we take everything that is XML, JSON or osc ;)
module RoutesHelper
  class APIMatcher
    def self.matches?(request)
      format = request.format.to_sym || :xml
      format == :xml || format == :json || formatless_path?(request)
    end

    # We serve those routes to all requested formats...
    def self.formatless_path?(request)
      request.fullpath.start_with?('/public', '/about', '/build')
    end
  end
end
