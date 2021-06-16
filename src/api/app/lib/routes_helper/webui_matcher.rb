require 'api_error'

module RoutesHelper
  class WebuiMatcher
    class InvalidRequestFormat < APIError
    end

    def self.matches?(request)
      request.format.to_sym != :xml
    rescue ArgumentError => e
      raise InvalidRequestFormat, e.to_s
    end
  end
end
