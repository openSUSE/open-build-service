class OutdatedNotificationsFinder::Appeal
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    @scope.where(notifiable_type: 'Appeal', notifiable_id: @parameters[:notifiable_id])
  end
end
