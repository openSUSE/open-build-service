class OutdatedNotificationsFinder::Package
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    @scope.where(notifiable_type: 'Package', notifiable_id: @parameters[:notifiable_id])
  end
end
