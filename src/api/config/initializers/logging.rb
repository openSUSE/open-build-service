# frozen_string_literal: true

module APIInstrumentation
  module ControllerRuntime
    extend ActiveSupport::Concern

    protected

    def append_info_to_payload(payload)
      super
      payload[:backend_runtime] = Backend::Logger.runtime * 1000
      payload[:xml_runtime] = ActiveXML::Node.runtime * 1000
      Backend::Logger.reset_runtime
      ActiveXML::Node.reset_runtime
      runtime = { view: payload[:view_runtime], db: payload[:db_runtime], backend: payload[:backend_runtime], xml: payload[:xml_runtime] }
      response.headers['X-Opensuse-Runtimes'] = ActiveSupport::JSON.encode(runtime)
    end

    module ClassMethods
      def log_process_action(payload)
        messages = super
        backend_runtime = payload[:backend_runtime]
        xml_runtime = payload[:xml_runtime]
        messages << format('Backend: %.1fms', backend_runtime.to_f) if backend_runtime
        messages << format('XML: %.1fms', xml_runtime.to_f) if xml_runtime
        messages
      end
    end
  end
end

module TimestampFormatter
  def call(severity, timestamp, progname, msg)
    Thread.current[:timestamp_formatter_timestamp] ||= Time.now
    tdiff = format('%02.2f', Time.now - Thread.current[:timestamp_formatter_timestamp])
    super(severity, timestamp, progname, "[#{Process.pid}:#{tdiff}] #{msg}")
  end
end

ActiveSupport.on_load(:action_controller) do
  include APIInstrumentation::ControllerRuntime
  Rails.logger.formatter.extend(TimestampFormatter)
end
