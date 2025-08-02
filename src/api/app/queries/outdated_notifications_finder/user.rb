class OutdatedNotificationsFinder::User
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    @scope.where(notifiable_type: 'User', notifiable_id: @parameters[:notifiable_id])
  end
end
