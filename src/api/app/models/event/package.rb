module Event
  class Package < Base
    self.description = 'Package was touched'
    payload_keys :project, :package, :sender
  end
end