class OutdatedNotificationsFinder::Project
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    @scope.where(notifiable_type: 'Project', notifiable_id: @parameters[:notifiable_id])
  end
end
