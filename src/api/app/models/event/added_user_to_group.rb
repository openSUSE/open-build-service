module Event
  class AddedUserToGroup < Base
    self.description = 'Added user to group'
    payload_keys :group, :user, :who

    receiver_roles :user

    def subject
      "You were added to the group '#{payload['group']}'" unless payload['who']

      "'#{payload['who']}' added you to the group '#{payload['group']}'"
    end

    def users
      [User.find_by(login: payload['user'])]
    end
  end
end
