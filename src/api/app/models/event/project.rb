module Event
  class Project < Base
    self.description = 'Project was touched'
    payload_keys :project
  end

  class CreateProject < Project
    self.raw_type = 'SRCSRV_CREATE_PROJECT'
    self.description = 'Project is created'
    payload_keys :sender

    create_jobs :cleanup_cache_lines

    def subject
      "New Project #{payload['project']}"
    end
  end

  class UpdateProjectConfig < Project
    self.raw_type = 'SRCSRV_UPDATE_PROJECT_CONFIG'
    self.description = 'Project _config was updated'
    payload_keys :sender, :files, :comment
  end

  class UndeleteProject < Project
    self.raw_type = 'SRCSRV_UNDELETE_PROJECT'
    self.description = 'Project was undeleted'
    payload_keys :comment, :sender

    create_jobs :cleanup_cache_lines
  end

  class UpdateProject < Project
    self.raw_type = 'SRCSRV_UPDATE_PROJECT'
    self.description = 'Project meta was updated'
    payload_keys :sender
  end

  class DeleteProject < Project
    self.raw_type = 'SRCSRV_DELETE_PROJECT'
    self.description = 'Project was deleted'
    payload_keys :comment, :requestid, :sender

    create_jobs :cleanup_cache_lines
  end
end

