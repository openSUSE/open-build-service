#replaces CGI.unescape with URI.unescape to prevent unescaping '+' to ' ' in path elements

module ActionController
  module Routing
    class DynamicComponent
      def assign_result(g, with_default = false)
        g.result key, "URI.unescape(#{g.next_segment(true, with_default ? default : nil)})"
        g.move_forward {|gp| yield gp}
      end
    end
  end
end
