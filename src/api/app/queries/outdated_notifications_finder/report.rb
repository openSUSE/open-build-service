class OutdatedNotificationsFinder::Report
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    @scope.where(notifiable_type: 'Report', notifiable_id: @parameters[:notifiable_id])
  end
end
