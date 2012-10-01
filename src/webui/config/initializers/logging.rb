#
# Improve logging layout
#
module ActiveSupport

  class BufferedLogger
    NUMBER_TO_NAME_MAP  = {0=>'DEBUG', 1=>'INFO', 2=>'WARN', 3=>'ERROR', 4=>'FATAL', 5=>'UNKNOWN'}
    NUMBER_TO_COLOR_MAP = {0=>'0;37', 1=>'32', 2=>'33', 3=>'31', 4=>'31', 5=>'37'}

    def add(severity, message = nil, progname = nil, &block)
      return if self.level > severity
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

module APIInstrumentation
  module ControllerRuntime
    extend ActiveSupport::Concern

    protected

    def append_info_to_payload(payload)
      super
      payload[:transport_details] = ActiveXML::Config.transport_for( :project ).details.summary!
      payload[:xml_runtime] = ActiveXML::LibXMLNode.runtime * 1000
      ActiveXML::LibXMLNode.reset_runtime
      runtime = payload[:transport_details].clone
      runtime[:view] = payload[:view_runtime]
      runtime[:xml] = payload[:xml_runtime]
      runtime.each_key do |key|
        runtime[key] = Integer(runtime[key].to_f * 10 + 0.5).to_f / 10
      end
      response.headers["X-Opensuse-Runtimes"] = runtime.to_json
    end

    module ClassMethods
      def log_process_action(payload)
        messages, api_runtime, xml_runtime = super, payload[:transport_details], payload[:xml_runtime]
        if api_runtime
          apis = []
          apis << ("XML: %.1fms" % api_runtime["api-xml"].to_f) if api_runtime["api-xml"]
          apis << ("View: %.1fms" % api_runtime["api-view"].to_f) if api_runtime["api-view"]
          apis << ("Backend: %.1fms" % api_runtime["api-backend"].to_f) if api_runtime["api-backend"]
          apis << ("DB: %.1fms" % api_runtime["api-db"].to_f) if api_runtime["api-db"]
          apis << ("HTTP: %.1fms" % (api_runtime["api-all"].to_f - api_runtime["api-runtime"].to_f)) if (api_runtime["api-all"] && api_runtime["api-runtime"])
          messages << "API: %.1fms (#{apis.join(' , ')})" % api_runtime["api-all"] if api_runtime["api-all"]
        end
        messages << ("XML: %.1fms" % xml_runtime.to_f) if xml_runtime
        messages
      end
    end
  end
end

ActiveSupport.on_load(:action_controller) do
  include APIInstrumentation::ControllerRuntime
end
