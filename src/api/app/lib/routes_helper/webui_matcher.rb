module RoutesHelper
  class WebuiMatcher
    def self.matches?(request)
      request.format.to_sym != :xml || formatless_path?(request)
    rescue ArgumentError => e
      raise InvalidRequestFormat, e.to_s
    end

    # We serve those routes to all requested formats...
    def self.formatless_path?(request)
      request.fullpath.start_with?('/sitemaps', '/project/sitemap', '/package/sitemap')
    end
  end
end
