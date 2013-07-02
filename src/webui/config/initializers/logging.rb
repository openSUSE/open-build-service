module APIInstrumentation
  module ControllerRuntime
    extend ActiveSupport::Concern

    protected

    def append_info_to_payload(payload)
      super
      payload[:transport_details] = ActiveXML::transport.details.summary!
      payload[:xml_runtime] = ActiveXML::Node.runtime * 1000
      ActiveXML::Node.reset_runtime
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

