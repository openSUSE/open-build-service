module Event
  class Project < Base
    self.description = 'Project was touched'
    payload_keys :project
  end

  class CreateProject < Project
    self.raw_type = 'SRCSRV_CREATE_PROJECT'
    self.description = 'Project is created'
    payload_keys :sender
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.project.create"
    end

    def subject
      "New Project #{payload['project']}"
    end
  end

  class UpdateProjectConfig < Project
    self.raw_type = 'SRCSRV_UPDATE_PROJECT_CONFIG'
    self.description = 'Project _config was updated'
    payload_keys :sender, :files, :comment
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.project.update_project_conf"
    end
  end

  class UndeleteProject < Project
    self.raw_type = 'SRCSRV_UNDELETE_PROJECT'
    self.description = 'Project was undeleted'
    payload_keys :comment, :sender
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.project.undelete"
    end
  end

  class UpdateProject < Project
    self.raw_type = 'SRCSRV_UPDATE_PROJECT'
    self.description = 'Project meta was updated'
    payload_keys :sender
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.project.update"
    end
  end

  class DeleteProject < Project
    self.raw_type = 'SRCSRV_DELETE_PROJECT'
    self.description = 'Project was deleted'
    payload_keys :comment, :requestid, :sender
    after_commit :send_to_bus

    def self.message_bus_queue
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
