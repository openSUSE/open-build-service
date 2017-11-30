module Event
  class UpdateProjectConfig < Project
    self.description = 'Project _config was updated'
    payload_keys :sender, :files, :comment
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.update_project_conf"
    end
  end
end
