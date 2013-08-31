class Event::Project < ::Event::Base
  self.description = 'Project was touched'
  payload_keys :project
end

class Event::CreateProject < Event::Project
  self.raw_type = 'SRCSRV_CREATE_PROJECT'
  self.description = 'Project is created'
  payload_keys :sender
end

class Event::UpdateProjectConfig < Event::Project
  self.raw_type = 'SRCSRV_UPDATE_PROJECT_CONFIG'
  self.description = 'Project _config was updated'
  payload_keys :sender, :files, :comment
end

class Event::UndeleteProject < Event::Project
  self.raw_type = 'SRCSRV_UNDELETE_PROJECT'
  self.description = 'Project was undeleted'
  payload_keys :comment, :sender
end

class Event::UpdateProject < Event::Project
  self.raw_type = 'SRCSRV_UPDATE_PROJECT'
  self.description = 'Project meta was updated'
  payload_keys :sender
end

class Event::DeleteProject < Event::Project
  self.raw_type = 'SRCSRV_DELETE_PROJECT'
  self.description = 'Project was deleted'
  payload_keys :comment, :requestid, :sender
end
