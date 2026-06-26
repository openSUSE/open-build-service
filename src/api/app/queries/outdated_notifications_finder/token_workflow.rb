class OutdatedNotificationsFinder::TokenWorkflow
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  def call
    @scope.where(notifiable_type: 'Token::Workflow', notifiable_id: @parameters[:notifiable_id])
  end
end
