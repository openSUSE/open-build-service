#
# Improve logging layout
#
module ActiveSupport

  class BufferedLogger
    NUMBER_TO_NAME_MAP  = {0=>'DEBUG', 1=>'INFO', 2=>'WARN', 3=>'ERROR', 4=>'FATAL', 5=>'UNKNOWN'}
    NUMBER_TO_COLOR_MAP = {0=>'0;37', 1=>'32', 2=>'33', 3=>'31', 4=>'31', 5=>'37'}

    def add(severity, message = nil, progname = nil, &block)
      return if @level > severity
      sevstring = NUMBER_TO_NAME_MAP[severity]
      color = NUMBER_TO_COLOR_MAP[severity]
      message = (message || (block && block.call) || progname).to_s
      prefix=""
      while message[0] == 13 or message[0] == 10
        prefix = prefix.concat(message[0])
        message = message[1..-1]
      end
   
      message = prefix + "[\033[#{color}m%-5s\033[0m|#%5d] %s" % [sevstring, $$, message]
      @log.add(severity, message, progname, &block)
    end
  end
end

module ActionController
  module Benchmarking
    
    def view_runtime
      brt = Suse::Backend.runtime * 1000
      xrt = ActiveXML::LibXMLNode.runtime * 1000
      # this is the most stupid place to put it, but there is no other code path
      # without monkey patching _heavily_ the benckmarking module
      Suse::Backend.reset_runtime
      ActiveXML::LibXMLNode.reset_runtime
      "Backend: %.0f, View: %.0f, XML: %.0f" % [brt, @view_runtime, xrt]
    end

  end
end
