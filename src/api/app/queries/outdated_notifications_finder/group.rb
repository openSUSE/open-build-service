class OutdatedNotificationsFinder::Group
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    # Only replace the notification if it's identical: same member added/removed from the same group by the same person.
    # That's why we need to compare with both event_type and event_payload.
    @scope.where(notifiable_type: 'Group', notifiable_id: @parameters[:notifiable_id],
                 event_type: @parameters[:event_type], event_payload: @parameters[:event_payload])
  end
end
