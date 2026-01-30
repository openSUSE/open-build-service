class OutdatedNotificationsFinder::Token
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    @scope.where(notifiable_type: @parameters[:notifiable_type], notifiable_id: @parameters[:notifiable_id])
  end
end
