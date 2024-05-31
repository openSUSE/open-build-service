module Event
  class AddedUserToGroup < Base
    self.description = 'Added user to group'
    payload_keys :group, :user

    receiver_roles :user

    def subject
      "You've been added to the group #{payload['group']}"
    end

    def users
      [User.find_by(login: payload['user'])]
    end
  end
end
