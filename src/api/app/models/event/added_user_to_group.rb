module Event
  class AddedUserToGroup < Base
    self.message_bus_routing_key = 'groups_user.create'
    self.description = 'Added user to group'
    payload_keys :group, :user

    def subject
      "You've been added to the group #{payload['group']}"
    end
  end
end
