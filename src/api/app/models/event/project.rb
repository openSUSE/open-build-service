module Event
  class Project < Base
    self.description = 'Project was touched'
    payload_keys :project
  end

  class CreateProject < Project
    self.description = 'Project is created'
    payload_keys :sender
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.create"
    end

    def subject
      "New Project #{payload['project']}"
    end
  end

  class UpdateProjectConfig < Project
    self.description = 'Project _config was updated'
    payload_keys :sender, :files, :comment
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.update_project_conf"
    end
  end

  class UndeleteProject < Project
    self.description = 'Project was undeleted'
    payload_keys :comment, :sender
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.undelete"
    end
  end

  class UpdateProject < Project
    self.description = 'Project meta was updated'
    payload_keys :sender
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.update"
    end
  end

  class DeleteProject < Project
    self.description = 'Project was deleted'
    payload_keys :comment, :requestid, :sender
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.delete"
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id             :integer          not null, primary key
#  eventtype      :string(255)      not null, indexed
#  payload        :text(65535)
#  created_at     :datetime         indexed
#  updated_at     :datetime
#  project_logged :boolean          default(FALSE), indexed
#  undone_jobs    :integer          default(0)
#  mails_sent     :boolean          default(FALSE), indexed
#
# Indexes
#
#  index_events_on_created_at      (created_at)
#  index_events_on_eventtype       (eventtype)
#  index_events_on_mails_sent      (mails_sent)
#  index_events_on_project_logged  (project_logged)
#
