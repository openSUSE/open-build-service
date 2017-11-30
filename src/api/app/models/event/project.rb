module Event
  class Project < Base
    self.description = 'Project was touched'
    payload_keys :project
  end
end
