module APIInstrumentation
  module ControllerRuntime
    protected

    def append_info_to_payload(payload)
      super
      payload[:backend_runtime] = Backend::Connection.runtime
      Backend::Connection.reset_runtime
      runtime = { view: payload[:view_runtime], db: payload[:db_runtime], backend: payload[:backend_runtime] }
      response.headers['X-Opensuse-Runtimes'] = ActiveSupport::JSON.encode(runtime)
    end
  end
end

ActiveSupport.on_load(:action_controller) do
  include APIInstrumentation::ControllerRuntime
end
