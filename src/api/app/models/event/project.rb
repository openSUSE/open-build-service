module Event
  class Project < Base
    self.description = 'Project was touched'
    payload_keys :project
  end

  class CreateProject < Project
    self.description = 'Project is created'
    self.amqp_name = 'project.create'
    payload_keys :sender

    create_jobs :cleanup_cache_lines

    def subject
      "New Project #{payload['project']}"
    end
  end

  class UpdateProjectConfig < Project
    self.description = 'Project _config was updated'
    self.amqp_name = 'project.update_project_config'
    payload_keys :sender, :files, :comment
  end

  class UndeleteProject < Project
    self.description = 'Project was undeleted'
    self.amqp_name = 'project.undelete'
    payload_keys :comment, :sender

    create_jobs :cleanup_cache_lines
  end

  class UpdateProject < Project
    self.description = 'Project meta was updated'
    self.amqp_name = 'project.update'
    payload_keys :sender
  end

  class DeleteProject < Project
    self.description = 'Project was deleted'
    self.amqp_name = 'project.delete'
    payload_keys :comment, :requestid, :sender

    create_jobs :cleanup_cache_lines
  end
end

# == Schema Information
#
# Table name: events
#
#  id             :integer          not null, primary key
#  eventtype      :string(255)      not null, indexed
#  payload        :text(65535)
#  queued         :boolean          default(FALSE), not null, indexed
#  lock_version   :integer          default(0), not null
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
#  index_events_on_queued          (queued)
#
