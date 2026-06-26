module Event
  class Group < Base
    self.abstract_class = true
    payload_keys :group, :member, :who
    receiver_roles :member, :group_maintainer

    def subject
      raise AbstractMethodCalled
    end

    def members
      User.where(login: payload['member'])
    end

    def group_maintainers
      ::Group.find_by(title: payload['group']).maintainers
    end

    def originator
      payload_address('who')
    end

    def parameters_for_notification
      super.merge({ notifiable_type: 'Group',
                    notifiable_id: ::Group.find_by(title: payload['group']).id,
                    type: 'NotificationGroup' })
    end

    def event_object
      ::Group.find_by(name: payload['group'])
    end
  end
end
