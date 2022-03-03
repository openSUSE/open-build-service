module Event
  class Relationship < Base
    self.abstract_class = true
    payload_keys :description, :who, :user, :group, :project, :package, :role
    shortenable_key :description
  end
end
