class OutdatedNotificationsFinder::Decision
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    @scope.where(notifiable_type: 'Decision', notifiable_id: @parameters[:notifiable_id])
  end
end
