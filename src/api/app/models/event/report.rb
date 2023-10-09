module Event
  class Report < Base
    receiver_roles :moderator
    self.description = 'Report for inappropriate content has been created'

    payload_keys :id, :user_id, :reportable_id, :reportable_type, :reason

    def parameters_for_notification
      super.merge(notifiable_type: 'Report')
    end
  end
end
