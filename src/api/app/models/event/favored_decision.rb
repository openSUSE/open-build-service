module Event
  class FavoredDecision < Base
    receiver_roles :reporter, :offender
    self.description = 'Reported content has been favored'

    payload_keys :id, :reason, :moderator_id, :reportable_type

    def parameters_for_notification
      super.merge(notifiable_type: 'Decision')
    end
  end
end
