class OutdatedNotificationsFinder::Group
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    # Notifications about added members shouldn't replace notifications about removed members and vice versa, so event_type should match.
    @scope.where(notifiable_type: 'Group', notifiable_id: @parameters[:notifiable_id], event_type: @parameters[:event_type])
  end
end
