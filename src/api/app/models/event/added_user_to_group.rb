module Event
  class AddedUserToGroup < Base
    self.description = 'Added user to group'
    payload_keys :group, :user

    def subject
      "You've been added to the group #{payload['group']}"
    end
  end
end
