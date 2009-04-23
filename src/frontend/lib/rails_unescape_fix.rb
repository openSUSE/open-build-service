#replaces CGI.unescape with URI.unescape to prevent unescaping '+' to ' ' in path elements
require 'uri'

# patched version of the original code from /usr/lib*/ruby/gems/1.8/gems/actionpack-1.13.3/lib/action_controller/routing.rb
module ActionController
  module Routing
    class PathSegment < DynamicSegment #:nodoc:
      class Result < ::Array #:nodoc:
        def self.new_escaped(strings)
          new strings.collect {|str| URI.unescape str}
        end
      end
    end
    class RouteSet #:nodoc:
      def recognize_path(path, environment={})
        path = URI.unescape(path)
        routes.each do |route|
          result = route.recognize(path, environment) and return result
        end
        raise RoutingError, "no route found to match #{path.inspect} with #{environment.inspect}"
      end
    end
  end
end
