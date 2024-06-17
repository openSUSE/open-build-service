module Event
  class AddedUserToGroup < Base
    self.description = 'Added member to group'
    payload_keys :group, :member, :who

    receiver_roles :member

    self.notification_explanation = 'Receive notifications when you are added to a group.'

    def subject
      "You were added to the group '#{payload['group']}'" unless payload['who']

      "'#{payload['who']}' added you to the group '#{payload['group']}'"
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
