module Event
  class GlobalRoleAssigned < Base
    self.description = 'User received an important role'
    payload_keys :role, :user, :who
  end
end
