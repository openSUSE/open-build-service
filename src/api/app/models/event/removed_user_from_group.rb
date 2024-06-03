module Event
  class RemovedUserFromGroup < Base
    self.description = 'Removed user from group'
    payload_keys :group, :user, :who

    receiver_roles :user

    def subject
      "You were removed from the group '#{payload['group']}'" unless payload['who']

      "'#{payload['who']}' removed you from the group '#{payload['group']}'"
    end

    def users
      [User.find_by(login: payload['user'])]
    end

    def originator
      payload_address('who')
    end

    def parameters_for_notification
      super.merge({ notifiable_type: 'Group',
                    notifiable_id: Group.find_by(title: payload['group']).id })
    end
  end
end
