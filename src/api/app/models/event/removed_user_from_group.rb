module Event
  class RemovedUserFromGroup < Base
    self.description = 'Removed user from group'
    payload_keys :group, :user

    receiver_roles :user

    def subject
      "You've been removed from the group #{payload['group']}"
    end

    def users
      [User.find_by(login: payload['user'])]
    end
  end
end
