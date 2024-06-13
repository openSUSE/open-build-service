module Event
  class RemovedUserFromGroup < Base
    self.description = 'Removed member from group'
    payload_keys :group, :member, :who

    receiver_roles :member

    self.notification_explanation = 'Receive notifications when you are removed from a group.'

    def subject
      "You were removed from the group '#{payload['group']}'" unless payload['who']

      "'#{payload['who']}' removed you from the group '#{payload['group']}'"
    end

    def members
      [User.find_by(login: payload['member'])]
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
