module Event
  class ClearedDecision < Base
    receiver_roles :reporter
    self.description = 'Reported content has been cleared'

    payload_keys :id, :reason, :moderator_id

    def parameters_for_notification
      super.merge(notifiable_type: 'Decision')
    end
  end
end
